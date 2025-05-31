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
  nodejs npm \
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
  chmod g+w /etc/passwd

USER ${USER}

# Install random stuff for the user
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN \
  # Install getnf for installation of Nerd Fonts later
  curl -fsSL https://raw.githubusercontent.com/getnf/getnf/main/install.sh | /bin/bash 
# /home/lenus/.local/bin/getnf -g -i FiraCode && \

# Set up a Python venv
WORKDIR ${WORK_DIR}
RUN mkdir ./.envs

WORKDIR ${WORK_DIR}/.envs
RUN uv venv -p 3.13 dev

COPY ./configs /home/${USER}/.config

