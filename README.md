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

## Clipboard support

`pydev-container` is a small Go launcher and clipboard client. It provides one
workflow for Windows, macOS, X11 Linux, and Wayland Linux without mounting a
display socket into the container. The launcher starts a short-lived,
token-protected clipboard bridge on the host; the container receives only that
bridge URL and its randomly generated token.

This avoids the platform-specific X11 and Wayland socket mounts. On Linux, the
**host** must provide either `wl-clipboard` (`wl-copy`/`wl-paste`) for Wayland
or `xclip` for X11. macOS uses `pbcopy`/`pbpaste`, and Windows uses PowerShell's
built-in clipboard commands.

### Install and build

Install the launcher on the host with Go 1.23 or later:

```sh
go install ./cmd/pydev-container
```

Ensure Go's bin directory is on your `PATH` (normally `$(go env GOPATH)/bin`).
Then build the image. The same binary is installed in the image so it is
available to Neovim and the shell inside the container.

```sh
docker build -t pydev-container .
```

### Run a mounted workspace

Pass the host path explicitly. It is mounted at `/workspace` by default and
becomes the container's working directory:

```sh
pydev-container run --path /absolute/path/to/project
```

Use `--target` to select a different mount point, and add a command after `--`
to override the image entrypoint:

```sh
pydev-container run --path ~/src/my-project --target /work -- nvim README.md
```

Inside a launched container, use:

```sh
printf 'copied from the container' | pydev-container clipboard copy
pydev-container clipboard paste
```

Neovim is configured to use this client automatically for the `+` and `*`
registers, so normal yanks and pastes use the host clipboard.

### Updating the launcher

After changing `cmd/pydev-container`, reinstall the host launcher and rebuild
the image so the host and container clients stay in sync:

```sh
go install ./cmd/pydev-container
docker build -t pydev-container .
```

The bridge listens on an ephemeral port for the lifetime of the `run` command.
It requires the per-container token for every request; do not manually expose
that port or token to untrusted processes. The selected bind mount is writable
by default, so pass only directories you intend the container to modify.

## Publishing the Docker image

The GitHub Actions workflow publishes `lowcloudnine/drauprin` on pushes to
`main`, version tags beginning with `v`, or a manual workflow dispatch. Before
the first run, create a Docker Hub access token with permission to push to that
repository and save it as the GitHub repository secret `DOCKERHUB_TOKEN`.

The workflow publishes `latest` from `main`. A tag such as `v1.2.3` also
publishes `1.2.3`, `1.2`, and `1`.
