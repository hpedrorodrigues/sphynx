#!/usr/bin/env bash

# Loading internal files

readonly library_path="${SPHYNX_COMMAND_DIR}/.internal/library"

source "${library_path}/docopts.sh"
source "${library_path}/error.sh"
source "${library_path}/file_handling.sh"
source "${library_path}/general.sh"
source "${library_path}/git.sh"
source "${library_path}/github.sh"
source "${library_path}/logging.sh"
source "${library_path}/network.sh"
source "${library_path}/os.sh"
source "${library_path}/osx.sh"
source "${library_path}/repl.sh"
source "${library_path}/requirements.sh"
source "${library_path}/sphynx.sh"
source "${library_path}/string.sh"
source "${library_path}/formatter.sh"
source "${library_path}/math.sh"
source "${library_path}/url.sh"
source "${library_path}/variables.sh"

# Loading core functions for global commands

readonly global_commands_path="${SPHYNX_COMMAND_DIR}/.internal/global-commands"

source "${global_commands_path}/fmt.sh"
source "${global_commands_path}/lint.sh"
source "${global_commands_path}/prompt.sh"
source "${global_commands_path}/test.sh"
source "${global_commands_path}/version.sh"
