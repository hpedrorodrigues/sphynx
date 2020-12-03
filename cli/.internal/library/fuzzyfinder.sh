#!/usr/bin/env bash

export SX_FZF_ARGS="${SX_FZF_ARGS:---ansi --select-1 --no-preview --cycle}"

if [ "${TERM}" = 'xterm-256color' ] || [ "${TERM}" = 'screen-256color' ]; then
  export SX_FZF_CURRENT_BGCOLOR="${SX_FZF_CURRENT_BGCOLOR:-$(tput setab 0)}" # Black
  export SX_FZF_CURRENT_FGCOLOR="${SX_FZF_CURRENT_FGCOLOR:-$(tput setaf 6)}" # Cyan
  export SX_FZF_CURRENT_RESETCOLOR="${SX_FZF_CURRENT_RESETCOLOR:-$(tput sgr0)}"
else
  export SX_FZF_CURRENT_BGCOLOR="${SX_FZF_CURRENT_BGCOLOR:-\e[1;40m}" # Black
  export SX_FZF_CURRENT_FGCOLOR="${SX_FZF_CURRENT_FGCOLOR:-\e[1;36m}" # Cyan
  export SX_FZF_CURRENT_RESETCOLOR="${SX_FZF_CURRENT_RESETCOLOR:-\e[0m}"
fi
