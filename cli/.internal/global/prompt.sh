#!/usr/bin/env bash

function sx::self::prompt::find_available_commands() {
  find "${SPHYNXC_DIR}" \
    -maxdepth 2 \
    ! -path "${SPHYNXC_DIR}" \
    ! -path '*?/.*?' \
    -a -type f -a \( -perm -u=x -o -perm -g=x -o -perm -o=x \) \
    | sed "s#${SPHYNXC_DIR}/##g" \
    | sed 's#/# #g' \
    | sort
}

function sx::self::prompt() {
  if sx::os::is_command_available 'fzf'; then
    local -r selected="$(
      sx::self::prompt::find_available_commands \
        | fzf --preview-window=right:75% --preview "${SPHYNX_EXEC} \$(echo {}) --help"
    )"

    if [ -n "${selected}" ]; then
      sx::log::info "> ${SPHYNX_EXEC_NAME} ${selected}\n"

      # shellcheck disable=SC2086  # quote this to prevent word splitting
      exec "${SPHYNX_EXEC}" ${selected}
    fi
  else
    export PS3=$'\n''Please, choose the command to be executed: '$'\n'

    local options
    mapfile -t options < <(sx::self::prompt::find_available_commands)

    select selected in "${options[@]}"; do
      sx::log::info "> ${SPHYNX_EXEC_NAME} ${selected}\n"

      # shellcheck disable=SC2086  # quote this to prevent word splitting
      exec "${SPHYNX_EXEC}" ${selected}
      break
    done
  fi
}
