FROM fedora:latest

ENV USER=eitri
ENV WORK_DIR=/home/${USER}
ENV NVM_DIR=${WORK_DIR}/.nvm
ENV NVM_SYMLINK_CURRENT=true
ENV PATH=${WORK_DIR}/.local/bin:${WORK_DIR}/.cargo/bin:${NVM_DIR}/current/bin:${PATH}

# Match these to the account that will own bind-mounted files on the host.
# Podman needs --userns=keep-id at runtime as well; see the README.
ARG USER_UID=1000
ARG USER_GID=1000

# Keep package groups separate so the Fedora package transaction below remains
# easy to scan and maintain. These map the Arch package set to Fedora names.
ARG DNF_DOCUMENTATION_PACKAGES="man-db man-pages less"
ARG DNF_BUILD_PACKAGES="autoconf automake binutils bison cmake debugedit fakeroot file flex gawk gcc gcc-c++ gettext groff gzip libtool llvm m4 make openssl-devel patch perl-FindBin pkgconf sed texinfo valgrind which zlib-ng-compat-devel just clang"
ARG DNF_RUNTIME_PACKAGES="rust cargo uv golang"
ARG DNF_CLI_PACKAGES="eza bat zoxide fd-find fzf ripgrep ttyd btop"
ARG DNF_SYSTEM_PACKAGES="sudo git ansible"
ARG DNF_EDITOR_PACKAGES="neovim luarocks tree-sitter-cli"
ARG DNF_CLIPBOARD_PACKAGES="xclip wl-clipboard"

# Bring the rolling Fedora base up to date, install the equivalent toolchain,
# and include glibc debuginfo for native debugging. Fedora's debuginfo plugin
# enables the matching debug repositories automatically.
RUN dnf -y upgrade --refresh \
    && dnf -y install \
        dnf-plugins-core \
        ${DNF_DOCUMENTATION_PACKAGES} \
        ${DNF_BUILD_PACKAGES} \
        ${DNF_RUNTIME_PACKAGES} \
        ${DNF_CLI_PACKAGES} \
        ${DNF_SYSTEM_PACKAGES} \
        ${DNF_EDITOR_PACKAGES} \
        ${DNF_CLIPBOARD_PACKAGES} \
    && dnf -y debuginfo-install glibc \
    && dnf clean all \
    && rm -rf /var/cache/dnf

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

# Fedora does not package these four CLI tools in its standard repositories.
# Build Starship and Bottom from their upstream sources. Zellij publishes
# supported amd64 and arm64 Linux binaries; downloading its matching release
# avoids a costly and currently unreliable cross-platform Cargo compilation.
RUN cargo install --locked starship bottom \
    && case "$(uname -m)" in \
        x86_64) zellij_arch=x86_64 ;; \
        aarch64 | arm64) zellij_arch=aarch64 ;; \
        *) echo "Unsupported Zellij architecture: $(uname -m)" >&2; exit 1 ;; \
    esac \
    && curl --fail --location --silent --show-error \
        "https://github.com/zellij-org/zellij/releases/latest/download/zellij-${zellij_arch}-unknown-linux-musl.tar.gz" \
        | tar --extract --gzip --directory ${WORK_DIR}/.local/bin zellij \
    && chmod 0755 ${WORK_DIR}/.local/bin/zellij \
    && GOBIN=${WORK_DIR}/.local/bin go install github.com/jesseduffield/lazygit@latest \
    && rm -rf \
        ${WORK_DIR}/.cargo/registry \
        ${WORK_DIR}/.cargo/git \
        ${WORK_DIR}/go/pkg/mod \
        ${WORK_DIR}/go/pkg/sumdb

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
