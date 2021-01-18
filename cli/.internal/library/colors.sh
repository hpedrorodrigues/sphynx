#!/usr/bin/env bash

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
