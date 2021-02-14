#!/usr/bin/env bash

# This variable is used to set a custom prompt in commands that create a
# new shell session
# e.g docker exec
# e.g kubernetes exec
# e.g kubernetes shell
export SX_PS1="${SX_PS1:-\u@\h:\w }"

# This variable is passed to all commands that use FuzzyFinder
export SX_FZF_ARGS="${SX_FZF_ARGS:---ansi --select-1 --no-preview --cycle}"

# These variables are used in commands that are based on a state
# e.g tmux ls
# e.g kubernetes namespace --list
if [ "${TERM}" = 'xterm-256color' ] || [ "${TERM}" = 'screen-256color' ]; then
  export SX_CURRENT_ITEM_BGCOLOR="${SX_CURRENT_ITEM_BGCOLOR:-$(tput setab 0)}" # Black
  export SX_CURRENT_ITEM_FGCOLOR="${SX_CURRENT_ITEM_FGCOLOR:-$(tput setaf 6)}" # Cyan
  export SX_RESETCOLOR="${SX_RESETCOLOR:-$(tput sgr0)}"
else
  export SX_CURRENT_ITEM_BGCOLOR="${SX_CURRENT_ITEM_BGCOLOR:-\e[1;40m}" # Black
  export SX_CURRENT_ITEM_FGCOLOR="${SX_CURRENT_ITEM_FGCOLOR:-\e[1;36m}" # Cyan
  export SX_RESETCOLOR="${SX_RESETCOLOR:-\e[0m}"
fi

function sx::color::current_item::echo() {
  echo "${SX_CURRENT_ITEM_BGCOLOR}${SX_CURRENT_ITEM_FGCOLOR}${*}${SX_RESETCOLOR}"
}
