FROM archlinux:latest

# Lenus is the Irish god of healing, almost always identified with Mars
# -- https://en.wikipedia.org/wiki/Lenus
ENV USER=lenus

RUN \
  # Update the container, not a best practice but I want current stuff 
  pacman -Syu --noconfirm && \
  \
  # Install various packages via pacman
  pacman -Sy --noconfirm \
  \ 
  # System programs 
  sudo \
  # Terminal Multiplexers
  zellij \
  # Python stuff
  uv \
  # Node/Javascript stuff
  nodejs npm \
  # Neovim programs 
  neovim lazygit fzf ripgrep bottom tree-sitter-cli

# Add a user with sudo priviledges
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN \
  useradd --create-home ${USER} && \
  # echo "${USER}:changeme" | chpasswd && \
  usermod -aG wheel ${USER} && \
  echo "${USER} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers && \
  chmod 0440 /etc/sudoers && \
  chmod g+w /etc/passwd

