#!/usr/bin/env bash

function sx::nerdctl::pid() {
  sx::nerdctl::check_requirements

  if sx::os::is_command_available 'fzf'; then
    local -r options="$(sx::nerdctl::running_containers)"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No running containers found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf ${SX_FZF_ARGS})"
  else
    export PS3=$'\n''Type the respective container number: '$'\n'

    local options
    readarray -t options < <(sx::nerdctl::running_containers)

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No running containers found'
    fi

    select option in "${options[@]}"; do
      local -r selected="${option}"
      break
    done
  fi

  [ -n "${selected}" ] \
    && sx::nerdctl_command::pid "$(echo "${selected}" | awk '{ print $1 }')"
}

function sx::nerdctl_command::pid() {
  local -r container_id="${1}"

  nerdctl inspect --format '{{.State.Pid}}' "${container_id}"
}
