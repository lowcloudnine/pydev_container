# pydev_container

A container for Python development, with AstroNvim, uv, etc.

## Why?

I would like a Python development environment with all the "tools"
I need to work. It will need to be command line only and will have
a learning curve but can lead to less time configuring systems for
work and hopefully make me more productive.

## What?

First and foremost it is a docker container with all the associated
limitations. The second is a list of the specifications of the
container.

## Specifications

### System & Container

- **Image:** hub.docker.com/archlinux:latest
- **Shell:** Xonsh
- **Python:** uv (this allows the use of most modern Python versions)
- **Node:** nodejs, npm (these are for the LSPs to make nvim really useful)
- **VCS:** git, lazygit

### Xontribs for Xonsh

- xontrib-pm (an interface for package managers)
- xontrib-xlsd (ls beautification)
- xontrib-prompt_starship (starship prompt interface)
- xontrib-sh (shell integration)
- xontrib-argcomplete

### Python dependencies

The Python tools installed in the image are declared in `pyproject.toml` and
their resolved versions are pinned in `uv.lock`.

After changing `pyproject.toml`, regenerate the lock file with Python 3.14
available:

```sh
uv lock
```

To intentionally update the pinned versions of the existing dependencies, run:

```sh
uv lock --upgrade
```

Commit both `pyproject.toml` and `uv.lock`. The Docker build uses
`uv sync --locked`, so it will fail if the lock file is out of date rather than
silently changing the image's Python dependencies.

### Neovim

- AstroNvim
- ripgrep
- fd
- fzf
- bottom
- getnf (for managing nerd fonts) [is this needed]
