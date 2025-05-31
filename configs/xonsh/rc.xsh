# For debugging, set to False for minimal messaging
$XONSH_SHOW_TRACEBACK = True

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
$PATH.append("/home/wodan/.local/jdk/bin")
$PATH.append("/home/wodan/.local/maven/bin")

# -------------------------------------
# Load Xontribs
# -------------------------------------

# $XONSH_COLOR_STYLE = 'material'
xontrib load coreutils
xontrib load prompt_starship
xontrib load xlsd
xontrib load sh
xontrib load argcomplete

# ---- Configurations for Xontribs
$XLSD_SORT_METHOD = "directories_first"

# ---- Java Env Vars
$JAVA_HOME = "/home/wodan/.local/jdk"

# ---- Node Version Manager
# This ensures a stable symlink is always present for the currently
# activated Node version
$NVM_SYMLINK_CURRENT = "true"
$NVM_DIR = "/home/wodan/.nvm"
source-bash "/home/wodan/.nvm/nvm.sh"  # This loads nvm
# This ensures the current node is always used
$PATH.insert(0, $NVM_DIR + "/current/bin")

# ---- AstroNvim
# $NVIM_APPNAME = "AstroNvim"
$NVIM_APPNAME = "nvim"
# ---- kickstart.nvim | my "custom" nvim?
# $NVIM_APPNAME = "kickstart.nvim"

aliases["vi"] = "/home/wodan/.local/bin/nvim"
aliases["vid"] = "/usr/bin/vi -d"
aliases["nvim"] = "/home/wodan/.local/bin/nvim"
aliases["vim"] = "/home/wodan/.local/bin/nvim"
aliases["fd"] = "fdfind -E snap"

# ---- Python Env Activates
aliases["dev"] = "source-bash /home/wodan/.envs/dev/bin/activate"
aliases["ops"] = "source-bash /home/wodan/.envs/ops/bin/activate"
aliases["dj"] = "source-bash /home/wodan/.envs/dj/bin/activate"
aliases["sarser"] = "source-bash /home/wodan/Projects/budget/.sarser/bin/activate"

# -------------------------------------
# Activate a Default Python Env
# -------------------------------------

source-bash /home/wodan/.envs/dev/bin/activate

