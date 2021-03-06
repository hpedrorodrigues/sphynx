#!/usr/bin/env bash

function sx::docker::tmux::check_requirements() {
  sx::docker::check_requirements
  sx::library::tmux::check_requirements
}

function sx::docker::tmux() {
  sx::docker::tmux::check_requirements

  if sx::os::is_command_available 'fzf'; then
    local -r options="$(sx::docker::running_containers)"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No running containers found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf ${SX_FZF_ARGS})"
  else
    export PS3=$'\n''Type the respective container number: '$'\n'

    local options
    readarray -t options < <(sx::docker::running_containers)

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No running containers found'
    fi

    select option in "${options[@]}"; do
      local -r selected="${option}"
      break
    done
  fi

  if [ -n "${selected}" ]; then
    local -r id="$(echo "${selected}" | awk '{ print $1 }')"
    local -r name="$(echo "${selected}" | awk '{ print $2 }')"

    sx::docker_command::tmux "${id}" "${name}"
  fi
}

function sx::docker_command::tmux() {
  local -r container_id="${1}"
  local -r container_name="${2}"

  sx::library::tmux::new_splitted_window \
    "${container_name}/${container_id}" \
    "${SPHYNX_EXEC} docker logs --container '${container_id}'" \
    "${SPHYNX_EXEC} docker exec --container '${container_id}'"
}
