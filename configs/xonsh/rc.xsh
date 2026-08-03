# For debugging, set to False for minimal messaging
$XONSH_SHOW_TRACEBACK = True
$FOREIGN_ALIASES_SUPPRESS_SKIP_MESSAGE = True

# -------------------------------------
# Imports
# -------------------------------------

import os
import platform
from pathlib import Path

import psutil
from rich import print

# -------------------------------------
# Environment Variables
# -------------------------------------

def display_current_dir():
    """Used to alias pwd."""
    print(str(Path.cwd()))

# -------------------------------------
# Environment Variables
# -------------------------------------
$SHELL_TYPE = "best"
$STARSHIP_CONFIG = Path(__file__).parent / "starship_xonsh.toml"
_xonsh_inputrc = str(Path(__file__).parent / "inputrc")
os.environ["INPUTRC"] = _xonsh_inputrc
$INPUTRC = _xonsh_inputrc
$VI_MODE = True
# ---- fzf
skip_dirs = ".git,.venv,.idea,.vscode,__pycache__,node_modules,target"
$FZF_DEFAULT_OPTS = " ".join([
    "--style full",
    f"--walker-skip {skip_dirs}", 
    "--preview 'bat -n --color=always {}' ",
    "--bind 'ctrl-/:change-preview-window(hidden)'",
])

# ---- Path
$PATH.insert(0, "$HOME/.local/bin")
$PATH.append("$HOME/.cargo/bin")
$PATH.append("$HOME/go/bin")

# -------------------------------------
# Load Xontribs
# -------------------------------------

$XONTRIB_CD_LONG_DURATION = 2  # default

xontrib load autoxsh
xontrib load argcomplete
xontrib load back2dir
xontrib load clp
xontrib load cmd_done
xontrib load coreutils
xontrib load "fzf-completions"
# xontrib load direnv
xontrib load prompt_starship

# ---- Configurations for Xontribs
$XLSD_SORT_METHOD = "directories_first"

# ---- fzf widgets configuration
$fzf_history_binding = "c-r"  # Ctrl+R
$fzf_ssh_binding = "c-s"      # Ctrl+S
$fzf_file_binding = "c-t"      # Ctrl+T
$fzf_dir_binding = "c-g"      # Ctrl+G

$fzf_find_command = "fd"
$fzf_find_dirs_command = "fd -t d"

# -------------------------------------
# Aliases
# -------------------------------------

# Which neovim configuration to use
# This is the directory name in ~/.config
# $NVIM_APPNAME = "AstroNvim"

# aliases['nvim'] = "$HOME/.local/bin/nvim"
aliases['vi'] = "nvim"
aliases['vim'] = "nvim"
aliases["ovi"] = "/bin/vi"

aliases['cat'] = "bat"
aliases['ls'] = "eza"
aliases['ll'] = "eza -al"
aliases["fd"] = "fdfind -E snap"
aliases["pwd"] = display_current_dir 
aliases["tree"] = "tree -C -I '.git' -I '__pycache__' -I '*.egg-info'"

aliases["lgit"] = "lazygit"

# ---- Python Env Activates
aliases["dev"] = "source-bash $HOME/.envs/dev/bin/activate"

# -------------------------------------
# Ensure dev environment is available
# -------------------------------------

source-bash $HOME/.envs/dev/bin/activate

# -------------------------------------
# Automatically activate project virtual environments
# -------------------------------------

source @(Path(__file__).parent / "xshrc" / "auto_activate_virtualenv.xsh")

# -------------------------------------
# Activate zoxide
# -------------------------------------

execx($(zoxide init xonsh), 'exec', __xonsh__.ctx, filename='zoxide')
