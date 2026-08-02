FROM archlinux:latest

ENV USER=eitri
ENV WORK_DIR=/home/${USER}

# Install packages and clean up cache
RUN pacman -Syu --noconfirm \
    && pacman -S --noconfirm --needed base-devel \
    && pacman -S --noconfirm eza bat zoxide \
    && pacman -S --noconfirm sudo starship ttyd zellij uv nodejs npm go btop \
    && pacman -S --noconfirm neovim luarocks tree-sitter-cli git lazygit fzf fd ripgrep bottom \
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

USER ${USER}
WORKDIR ${WORK_DIR}

# Set up Python venv and install Python/Xonsh packages
RUN mkdir -p ${WORK_DIR}/.envs \
    && uv venv -p 3.14 ${WORK_DIR}/.envs/dev \
    && source ${WORK_DIR}/.envs/dev/bin/activate \
    && uv pip install \
        xonsh[full] \
        xonsh-autoxsh xonsh-direnv \
        xontrib-back2dir xontrib-clp xontrib-cmd-durations \
        xontrib-fzf-completions \
        xontrib-prompt_starship xontrib-sh xontrib-argcomplete \
        psutil rich click

# Install AstroNvim, every plugin imported by community.lua, and configured
# Mason tools while the image build still has network access.
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
        +qa

USER root
RUN chsh -s /home/${USER}/.envs/dev/bin/xonsh ${USER}
USER ${USER}

WORKDIR ${WORK_DIR}
ENTRYPOINT [ "/home/eitri/.envs/dev/bin/xonsh" ]
