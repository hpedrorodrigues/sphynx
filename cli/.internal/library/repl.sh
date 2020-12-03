#!/usr/bin/env bash

function sx::repl() {
  local -r caller_name="${FUNCNAME[1]}"
  sx::log::info "#|>|>|>|>|>|>|>|>  Entering REPL (${caller_name})  <|<|<|<|<|<|<|<|#"
  sx::log::info 'Type "exit" or just enter to get out of repl.'

  local user_command
  set +e

  while [ "${user_command:-}" != 'exit' ]; do
    sx::log::progress '> '
    read -e -r user_command

    if [ -z "${user_command}" ]; then
      break
    fi

    case ${user_command} in
      exit) ;;
      *)
        eval "${user_command}"
        ;;
    esac
  done

  set -e

  sx::log::info "\n#|>|>|>|>|>|>|>|>  Exitting REPL (${caller_name})  <|<|<|<|<|<|<|<|#\n"
}
