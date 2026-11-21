#!/usr/bin/env bash

function sx::select_one() {
  local -r prompt="${1:-Please, choose an option}"
  local -r header_lines="${2:-0}"

  local lines
  readarray -t lines

  if [ "${#lines[@]}" -le "${header_lines}" ]; then
    return 0
  fi

  if sx::os::is_command_available 'fzf'; then
    # shellcheck disable=SC2086  # quote this to prevent word splitting
    printf '%s\n' "${lines[@]}" | fzf --header-lines "${header_lines}" ${SX_FZF_ARGS}
  else
    export PS3=$'\n'"${prompt}: "$'\n'

    local selected
    select selected in "${lines[@]:header_lines}"; do
      if [ -z "${selected}" ]; then
        sx::log::err "Invalid option \"${REPLY}\". Please, type the number of the desired option."
        continue
      fi

      echo "${selected}"
      break
    done </dev/tty
  fi
}
