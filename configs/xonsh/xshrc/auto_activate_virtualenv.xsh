# Automatically activate a virtual environment found within two parent directories.

from pathlib import Path

_AUTO_VENV_NAMES = (".venv", "venv", "env")
_AUTO_VENV_BASE_PATH = list($PATH)
_AUTO_VENV_BASE_ENV = {
    name: __xonsh__.env.get(name)
    for name in ("VIRTUAL_ENV", "VIRTUAL_ENV_PROMPT")
}
_AUTO_VENV_ACTIVE = None


def _find_virtualenv(directory):
    """Find the closest virtual environment in directory or its two parents."""
    directory = Path(directory).resolve()
    for current_directory in (directory, *directory.parents[:2]):
        for env_name in _AUTO_VENV_NAMES:
            virtualenv = current_directory / env_name
            if (virtualenv / "bin" / "activate").is_file():
                return virtualenv
    return None


def _restore_base_virtualenv():
    __xonsh__.env["PATH"] = list(_AUTO_VENV_BASE_PATH)
    for name, value in _AUTO_VENV_BASE_ENV.items():
        if value is None:
            __xonsh__.env.pop(name, None)
        else:
            __xonsh__.env[name] = value


@events.on_chdir
def _auto_activate_virtualenv(olddir, newdir, **_):
    global _AUTO_VENV_ACTIVE

    virtualenv = _find_virtualenv(newdir)
    if virtualenv == _AUTO_VENV_ACTIVE:
        return

    _restore_base_virtualenv()
    _AUTO_VENV_ACTIVE = virtualenv
    if virtualenv is not None:
        __xonsh__.env["PATH"] = [str(virtualenv / "bin"), *_AUTO_VENV_BASE_PATH]
        __xonsh__.env["VIRTUAL_ENV"] = str(virtualenv)
        __xonsh__.env["VIRTUAL_ENV_PROMPT"] = f"({virtualenv.name}) "
