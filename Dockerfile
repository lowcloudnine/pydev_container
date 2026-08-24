FROM archlinux:latest

ENV USER=eitri
ENV WORK_DIR=/home/${USER}
ENV NVM_DIR=${WORK_DIR}/.nvm
ENV NVM_SYMLINK_CURRENT=true
ENV PATH=${WORK_DIR}/.local/bin:${NVM_DIR}/current/bin:${PATH}

# Match these to the account that will own bind-mounted files on the host.
# Podman needs --userns=keep-id at runtime as well; see the README.
ARG USER_UID=1000
ARG USER_GID=1000

# Package groups are build-time only; keeping them separate makes the single
# pacman transaction below easier to scan and maintain.
ARG PACMAN_DOCUMENTATION_PACKAGES="man-db man-pages less"
ARG PACMAN_BUILD_PACKAGES="base-devel cmake just clang llvm valgrind glibc-debug"
ARG PACMAN_RUNTIME_PACKAGES="rust uv go"
ARG PACMAN_CLI_PACKAGES="eza bat zoxide fd fzf ripgrep starship ttyd zellij btop"
ARG PACMAN_SYSTEM_PACKAGES="sudo git lazygit ansible"
ARG PACMAN_EDITOR_PACKAGES="neovim luarocks tree-sitter-cli bottom"
ARG PACMAN_CLIPBOARD_PACKAGES="xclip wl-clipboard"

# The official Arch image excludes man pages through NoExtract. Remove that
# exclusion before installing packages so manual pages are actually unpacked.
# Install packages and clean up cache.
RUN sed -i '/^NoExtract[[:space:]]*=.*usr\/share\/man\/\*/d' /etc/pacman.conf \
    && printf '\n[core-debug]\nInclude = /etc/pacman.d/mirrorlist\n' >> /etc/pacman.conf \
    && pacman -Syu --noconfirm \
    && pacman -S --noconfirm --needed \
        ${PACMAN_DOCUMENTATION_PACKAGES} \
        ${PACMAN_BUILD_PACKAGES} \
        ${PACMAN_RUNTIME_PACKAGES} \
        ${PACMAN_CLI_PACKAGES} \
        ${PACMAN_SYSTEM_PACKAGES} \
        ${PACMAN_EDITOR_PACKAGES} \
        ${PACMAN_CLIPBOARD_PACKAGES} \
    && rm -rf /var/cache/pacman/pkg/*

# Add a non-root user whose IDs can match the host account that owns a bind
# mount.  Matching both UID and GID lets the user create, modify, and delete
# files on that mount without making the container run as root.
RUN getent group ${USER_GID} > /dev/null || groupadd --gid ${USER_GID} ${USER} \
    && useradd --create-home --uid ${USER_UID} --gid ${USER_GID} ${USER} \
    && usermod -aG wheel ${USER} \
    && echo "${USER} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/${USER} \
    && chmod 0440 /etc/sudoers.d/${USER} \
    && echo "/home/${USER}/.envs/dev/bin/xonsh" >> /etc/shells

# Copy configs and set permissions
COPY ./configs /home/${USER}/.config
RUN chown -R ${USER}:${USER} /home/${USER}/.config
COPY --chown=${USER}:${USER} pyproject.toml uv.lock /tmp/uv-project/

USER ${USER}
WORKDIR ${WORK_DIR}

# Install the latest Node.js LTS release (which includes npm) through NVM.
# The `current` symlink keeps the selected Node.js version on PATH for xonsh.
RUN git clone --depth 1 https://github.com/nvm-sh/nvm.git ${NVM_DIR} \
    && . ${NVM_DIR}/nvm.sh \
    && nvm install --lts \
    && nvm alias default 'lts/*' \
    && npm cache clean --force

# Set up the Python/Xonsh environment from the locked project dependencies.
# Discard uv's download, wheel, and pip HTTP caches; the virtual environment
# remains intact.
RUN UV_PROJECT_ENVIRONMENT=${WORK_DIR}/.envs/dev \
    uv sync --project /tmp/uv-project --locked --no-dev --no-install-project --python 3.14 \
    && rm -rf /tmp/uv-project ${WORK_DIR}/.cache/uv ${WORK_DIR}/.cache/pip

# Install AstroNvim, every plugin imported by community.lua, and configured
# Mason tools while the image build still has network access. Keep installed
# plugins, parsers, and Mason tools; discard only build/download caches so they
# are not committed into this image layer.
RUN git clone --depth 1 https://github.com/AstroNvim/template ${WORK_DIR}/.config/nvim \
    && rm -rf ${WORK_DIR}/.config/nvim/.git \
    && cp ${WORK_DIR}/.config/community.lua ${WORK_DIR}/.config/nvim/lua/community.lua \
    && nvim --headless "+Lazy! sync" +qa \
    && nvim --headless "+MasonToolsInstallSync" +qa \
    && nvim --headless \
        '+lua local registry = require("mason-registry"); local missing = {}; for _, name in ipairs(require("astrocore").plugin_opts("mason-tool-installer.nvim").ensure_installed) do local ok, package = pcall(registry.get_package, name); if not ok or not package:is_installed() then table.insert(missing, name) end end; assert(#missing == 0, "Missing Mason tools: " .. table.concat(missing, ", "))' \
        +qa \
    && nvim --headless \
        '+lua require("lazy").load({ plugins = { "nvim-treesitter" } })' \
        '+lua local parsers, seen = {}, {}; for _, parser in ipairs(require("astrocore").config.treesitter.ensure_installed) do if not seen[parser] then seen[parser] = true; table.insert(parsers, parser) end end; local function installed() for _, parser in ipairs(parsers) do if #vim.api.nvim_get_runtime_file("parser/" .. parser .. ".so", false) == 0 then return false end end return true end; assert(vim.wait(600000, installed, 100), "Timed out waiting for Tree-sitter parsers")' \
        +qa! \
    && rm -rf \
        ${WORK_DIR}/.cache/nvim \
        ${WORK_DIR}/.cache/pip \
        ${WORK_DIR}/.cache/uv \
        ${WORK_DIR}/.npm \
        ${WORK_DIR}/.cargo/registry \
        ${WORK_DIR}/.cargo/git

USER root
RUN chsh -s /home/${USER}/.envs/dev/bin/xonsh ${USER}
USER ${USER}

WORKDIR ${WORK_DIR}
ENTRYPOINT [ "/home/eitri/.envs/dev/bin/xonsh" ]
