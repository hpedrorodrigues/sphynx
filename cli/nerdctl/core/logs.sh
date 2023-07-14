#!/usr/bin/env bash

function sx::nerdctl::logs() {
  sx::nerdctl::check_requirements

  local -r container_id="${1:-}"

  if [ -n "${container_id}" ]; then
    if sx::nerdctl::has_container "${container_id}"; then
      sx::nerdctl::logs \
        "${container_id}" \
        "$(sx::nerdctl::container_name "${container_id}")"
    else
      sx::log::fatal 'No such container'
    fi
  elif sx::os::is_command_available 'fzf'; then
    local -r options="$(sx::nerdctl::all_containers)"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No containers found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf ${SX_FZF_ARGS})"
  else
    export PS3=$'\n''Type the respective container number: '$'\n'

    local options
    readarray -t options < <(sx::nerdctl::all_containers)

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No containers found'
    fi

    select option in "${options[@]}"; do
      local -r selected="${option}"
      break
    done
  fi

  if [ -n "${selected}" ]; then
    local -r id="$(echo "${selected}" | awk '{ print $1 }')"
    local -r name="$(echo "${selected}" | awk '{ print $2 }')"

    sx::nerdctl_command::logs "${id}" "${name}"
  fi
}

function sx::nerdctl_command::logs() {
  local -r container_id="${1}"
  local -r container_name="${2}"

  local -r container_title="${container_name}/${container_id}"

  sx::log::info "Tailing logs from container \"${container_title}\"\n"

  nerdctl logs --tail 1000 --follow "${container_id}"
}
