#!/usr/bin/env bash

function sx::self::prompt::find_available_commands() {
  find "${SPHYNX_CLI_DIR}" \
    -maxdepth 2 \
    ! -path "${SPHYNX_CLI_DIR}" \
    ! -path '*/.library*' \
    ! -path '*/.internal*' \
    -a -type f -a \( -perm -u=x -o -perm -g=x -o -perm -o=x \) \
    | sed "s#${SPHYNX_CLI_DIR}/##g" \
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
      # shellcheck disable=SC2086  # quote this to prevent word splitting
      "${SPHYNX_EXEC}" ${selected} --help && echo -e '\n---\n' || true

      local arguments=''
      read -r -e -p "> ${SPHYNX_EXEC_NAME} ${selected} " arguments

      # shellcheck disable=SC2086  # quote this to prevent word splitting
      exec "${SPHYNX_EXEC}" ${selected} ${arguments}
    fi
  else
    export PS3=$'\n''Please, choose the command to be executed: '$'\n'

    local options
    readarray -t options < <(sx::self::prompt::find_available_commands)

    select selected in "${options[@]}"; do
      # shellcheck disable=SC2086  # quote this to prevent word splitting
      "${SPHYNX_EXEC}" ${selected} --help && echo -e '\n---\n' || true

      local arguments=''
      read -r -e -p "> ${SPHYNX_EXEC_NAME} ${selected} " arguments

      # shellcheck disable=SC2086  # quote this to prevent word splitting
      exec "${SPHYNX_EXEC}" ${selected} ${arguments}
      break
    done
  fi
}
