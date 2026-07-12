#!/usr/bin/env bash

function sx::flow::logs() {
  sx::flow::check_requirements

  local -r query="${1:-}"
  local -r follow="${2:-false}"
  local -r since="${3:-}"
  local -r not_before="${4:-}"
  local -r extra_flags="${5:-}"

  local flags=''
  if ${follow}; then
    flags+=' --follow'
  fi

  if [ -n "${since}" ]; then
    flags+=" --since ${since}"
  fi

  if [ -n "${not_before}" ]; then
    flags+=" --not-before ${not_before}"
  fi

  if sx::os::is_command_available 'fzf'; then
    local -r options="$(sx::flow::tasks "${query}" true)"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No tasks found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf --header-lines 1 ${SX_FZF_ARGS})"

    if [ -n "${selected}" ]; then
      local -r task="$(echo "${selected}" | awk '{ print $1 }')"

      sx::flow_command::logs "${task}" "${flags}" "${extra_flags}"
    fi
  else
    export PS3=$'\n''Please, choose the task: '$'\n'

    local options
    readarray -t options < <(
      sx::flow::tasks "${query}" false
    )

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No tasks found'
    fi

    select selected in "${options[@]}"; do
      if [ -z "${selected}" ]; then
        sx::log::err "Invalid option \"${REPLY}\". Please, type the number of the desired option."
        continue
      fi

      local -r task="$(echo "${selected}" | awk '{ print $1 }')"

      sx::flow_command::logs "${task}" "${flags}" "${extra_flags}"
      break
    done
  fi
}

function sx::flow_command::logs() {
  local -r task="${1}"
  local -r flags="${2:-}"
  local -r extra_flags="${3:-}"

  sx::log::info "Reading logs from task \"${task}\"\n"

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  sx::flow::cli logs --task "${task}" ${flags} ${extra_flags}
}
