FROM archlinux:latest

# Lenus is the Irish god of healing, almost always identified with Mars
# -- https://en.wikipedia.org/wiki/Lenus
ENV USER=lenus
ENV WORK_DIR=/home/${USER}

RUN \
  # Update the container, not a best practice but I want current stuff 
  pacman -Syu --noconfirm && \
  \
  # Install various packages via pacman
  pacman -Sy --noconfirm \
  \ 
  # System programs 
  sudo starship \
  # Terminal Multiplexers
  zellij \
  # Python stuff
  uv \
  # Node/Javascript stuff
  nodejs npm tree-sitter-cli \
  # Neovim programs 
  neovim tree-sitter-cli lazygit fzf fd ripgrep bottom 

# Add a user with sudo priviledges
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN \
  useradd --create-home ${USER} && \
  # echo "${USER}:changeme" | chpasswd && \
  usermod -aG wheel ${USER} && \
  echo "${USER} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers && \
  chmod 0440 /etc/sudoers && \
  chmod g+w /etc/passwd && \
  echo "/home/${USER}/.envs/dev/bin/xonsh" >> /etc/shells

COPY ./configs /home/${USER}/.config
RUN chown -R ${USER}:${USER} ${WORK_DIR}/.config

USER ${USER}

# Set up a Python venv
WORKDIR ${WORK_DIR}
RUN mkdir ./.envs

WORKDIR ${WORK_DIR}/.envs
RUN \
  uv venv -p 3.13 dev && \
  source ${WORK_DIR}/.envs/dev/bin/activate && \
  uv pip install xonsh[full] \
  xontrib-prompt_starship xontrib-pm xontrib-xlsd xontrib-sh xontrib-argcomplete \
  psutil rich click && \
  nvim --headless +q && \
  nvim --headless +'AstroUpdate' +q && \
  nvim --headless +'Lazy! sync' +q && \
  nvim --headless +'Lazy! sync' +q 

USER root
RUN chsh -s /home/${USER}/.envs/dev/bin/xonsh ${USER} 
USER ${USER}

WORKDIR ${WORK_DIR}

ENTRYPOINT [ "/home/lenus/.envs/dev/bin/xonsh" ]

