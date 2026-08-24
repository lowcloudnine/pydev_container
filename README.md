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

- **Base Image:** hub.docker.com/archlinux:latest
- **Shell:** Xonsh
- **Python:** uv (this allows the use of most modern Python versions)
- **Node:** Used to install the latest LTS Node.js and npm, more flexible than
  simply installing nodejs and npm from pacman.
- **VCS:** git, lazygit

### Xontribs for Xonsh

- xontrib-pm (an interface for package managers)
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

## Publishing the Docker image

The GitHub Actions workflow publishes `lowcloudnine/drauprin` on pushes to
`main`, version tags beginning with `v`, or a manual workflow dispatch. Before
the first run, create a Docker Hub access token with permission to push to that
repository and save it as the GitHub repository secret `DOCKERHUB_TOKEN`.

The workflow publishes `latest` from `main`. A tag such as `v1.2.3` also
publishes `1.2.3`, `1.2`, and `1`.

## Using a local directory with Podman

Build the image with the same numeric user and group IDs as the account that
owns the local directory:

```sh
podman build \
  --build-arg USER_UID="$(id -u)" \
  --build-arg USER_GID="$(id -g)" \
  --tag draupnir .
```

Then run it with Podman's `keep-id` user namespace and bind-mount the local
directory. This gives the container user permission to read, write, and delete
files there (deletion also requires write permission on the directory itself):

```sh
podman run --rm -it \
  --userns=keep-id \
  --volume "$PWD:/workspace" \
  --workdir /workspace \
  draupnir
```

On an SELinux-enforcing host, append `:Z` to the volume specification (for
example, `--volume "$PWD:/workspace:Z"`) so Podman can relabel the mount for
container access.

### Using the published image

Users of the image published to Docker Hub do not need to rebuild it. Pull and
run the published image while mapping the invoking account's numeric IDs at
runtime:

```sh
podman run --rm -it \
  --userns=keep-id \
  --user "$(id -u):$(id -g)" \
  --volume "$PWD:/workspace" \
  --workdir /workspace \
  lowcloudnine/drauprin:latest
```

This lets the container read, create, modify, and delete files in the mounted
directory as the local user. On an SELinux-enforcing host, append `:Z` to the
volume specification.
