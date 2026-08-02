FROM archlinux:latest

ENV USER=eitri
ENV WORK_DIR=/home/${USER}

# Install packages and clean up cache
RUN pacman -Syu --noconfirm \
    && pacman -S --noconfirm --needed base-devel \
    && pacman -S --noconfirm go rust uv \
    && pacman -S --noconfirm nodejs npm \
    && pacman -S --noconfirm eza bat zoxide fd fzf ripgrep \
    && pacman -S --noconfirm sudo git lazygit \
    && pacman -S --noconfirm starship ttyd zellij btop \
    && pacman -S --noconfirm neovim luarocks tree-sitter-cli bottom \
    && rm -rf /var/cache/pacman/pkg/*

# Add user and set up sudoers safely
RUN useradd --create-home ${USER} \
    && usermod -aG wheel ${USER} \
    && echo "${USER} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/${USER} \
    && chmod 0440 /etc/sudoers.d/${USER} \
    && echo "/home/${USER}/.envs/dev/bin/xonsh" >> /etc/shells

# Copy configs and set permissions
COPY ./configs /home/${USER}/.config
RUN chown -R ${USER}:${USER} /home/${USER}/.config
COPY --chown=${USER}:${USER} pyproject.toml uv.lock ${WORK_DIR}/

USER ${USER}
WORKDIR ${WORK_DIR}

# Set up the Python/Xonsh environment from the locked project dependencies.
# Discard uv's download and wheel cache; the virtual environment remains intact.
RUN UV_PROJECT_ENVIRONMENT=${WORK_DIR}/.envs/dev \
    uv sync --locked --no-dev --no-install-project --python 3.14 \
    && rm -rf ${WORK_DIR}/.cache/uv

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
        '+lua require("nvim-treesitter").install(require("astrocore").config.treesitter.ensure_installed):wait(600000)' \
        +qa \
    && rm -rf \
        ${WORK_DIR}/.cache/nvim \
        ${WORK_DIR}/.cache/go-build \
        ${WORK_DIR}/.cache/uv \
        ${WORK_DIR}/.npm \
        ${WORK_DIR}/.cargo/registry \
        ${WORK_DIR}/.cargo/git \
        ${WORK_DIR}/go/pkg/mod/cache

USER root
RUN chsh -s /home/${USER}/.envs/dev/bin/xonsh ${USER}
USER ${USER}

WORKDIR ${WORK_DIR}
ENTRYPOINT [ "/home/eitri/.envs/dev/bin/xonsh" ]
