# For debugging, set to False for minimal messaging
$XONSH_SHOW_TRACEBACK = False 

# -------------------------------------
# Imports
# -------------------------------------


import os
import platform
import sys
from pathlib import Path

import psutil
from rich import print

# -------------------------------------
# Environment Variables
# -------------------------------------

$SHELL_TYPE = "best"
$STARSHIP_CONFIG = "~/.config/xonsh/starship_xonsh.toml"
$VI_MODE = True

# ---- Path
$PATH.append("/home/wodan/.local/bin")
$PATH.append("/home/wodan/.cargo/bin")
$PATH.append("/home/wodan/go/bin")

# -------------------------------------
# Load Xontribs
# -------------------------------------

# $XONSH_COLOR_STYLE = 'material'
xontrib load argcomplete
xontrib load coreutils
xontrib load pm
xontrib load prompt_starship
xontrib load sh
xontrib load xlsd

# ---- Configurations for Xontribs
$XLSD_SORT_METHOD = "directories_first"

# ---- AstroNvim
$NVIM_APPNAME = "nvim"

aliases["vi"] = "nvim"
aliases["vim"] = "nvim"

# ---- Python Env Activates
aliases["dev"] = "source-bash /home/lenus/.envs/dev/bin/activate"

# -------------------------------------
# Activate a Default Python Env
# -------------------------------------

source-bash /home/lenus/.envs/dev/bin/activate

