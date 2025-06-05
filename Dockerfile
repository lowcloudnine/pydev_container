FROM archlinux:latest

ENV USER=lenus
ENV WORK_DIR=/home/${USER}

# Install packages and clean up cache
RUN pacman -Syu --noconfirm \
    && pacman -S --noconfirm sudo starship zellij uv nodejs npm tree-sitter-cli neovim lazygit fzf fd ripgrep bottom \
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
RUN mkdir -p ./.envs \
    && uv venv -p 3.13 dev \
    && source ./.envs/dev/bin/activate \
    && uv pip install xonsh[full] xontrib-prompt_starship xontrib-pm xontrib-xlsd xontrib-sh xontrib-argcomplete psutil rich click \
    && nvim --headless +q \
    && nvim --headless +'AstroUpdate' +q \
    && nvim --headless +'Lazy! sync' +q

USER root
RUN chsh -s /home/${USER}/.envs/dev/bin/xonsh ${USER}
USER ${USER}

WORKDIR ${WORK_DIR}
ENTRYPOINT [ "/home/lenus/.envs/dev/bin/xonsh" ]
