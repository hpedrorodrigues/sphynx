#!/usr/bin/env bash

# This variable is used to set a custom prompt in commands that create a
# new shell session
# e.g. docker exec
# e.g. kubernetes exec
# e.g. kubernetes shell
export SX_PS1="${SX_PS1:-\u@\h:\w }"

# This variable is passed to all commands that use FuzzyFinder
export SX_FZF_ARGS="${SX_FZF_ARGS:---ansi --select-1 --no-preview --cycle}"

# These variables are used in commands that are based on a state
# e.g. tmux ls
# e.g. kubernetes namespace --list
# Similar to the `fzf` command: https://github.com/junegunn/fzf/blob/v0.65.0/src/tui/light_unix.go#L22-L29
if sx::os::is_command_available 'tput' && [[ "$(tput colors)" -ge 256 ]]; then
  export SX_CURRENT_ITEM_BGCOLOR="${SX_CURRENT_ITEM_BGCOLOR:-$(tput bold && tput setab 8)}" # Background: bright black (8)
  export SX_CURRENT_ITEM_FGCOLOR="${SX_CURRENT_ITEM_FGCOLOR:-$(tput setaf 15)}"             # Foreground: bright white (15)
  export SX_RESETCOLOR="${SX_RESETCOLOR:-$(tput sgr0)}"                                     # Reset attributes
else
  # Fallback using safe, widely supported ANSI escape codes.
  # Use closest available basic colors: black bg + bold white text.
  export SX_CURRENT_ITEM_BGCOLOR="${SX_CURRENT_ITEM_BGCOLOR:-$'\e[40m'}"   # Background: black
  export SX_CURRENT_ITEM_FGCOLOR="${SX_CURRENT_ITEM_FGCOLOR:-$'\e[1;37m'}" # Foreground: bright white (bold)
  export SX_RESETCOLOR="${SX_RESETCOLOR:-$'\e[0m'}"                        # Reset attributes
fi

function sx::color::current_item::echo() {
  echo "${SX_CURRENT_ITEM_BGCOLOR}${SX_CURRENT_ITEM_FGCOLOR}${*}${SX_RESETCOLOR}"
}
