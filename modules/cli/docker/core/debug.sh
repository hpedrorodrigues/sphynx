#!/usr/bin/env bash

function sx::docker::debug() {
  sx::docker::check_requirements

  local -r container_id="${1:-}"
  local -r image="${2:-}"

  if [ -n "${container_id}" ]; then
    if sx::docker::has_container "${container_id}"; then
      sx::docker_command::debug \
        "${container_id}" \
        "$(sx::docker::container_name "${container_id}")" \
        "${image}"
    else
      sx::log::fatal 'No such container'
    fi
  elif sx::os::is_command_available 'fzf'; then
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

    sx::docker_command::debug "${id}" "${name}" "${image}"
  fi
}

function sx::docker_command::debug() {
  local -r container_id="${1}"
  local -r container_name="${2}"
  local -r image="${3:-}"

  local -r container_title="${container_name}/${container_id}"

  if sx::os::is_command_available 'cdebug'; then
    sx::log::info "Debugging container \"${container_title}\" using cdebug\n"

    cdebug exec --privileged --image "${image}" -it "${container_id}"
  elif docker debug --help &>/dev/null; then
    sx::log::info "Debugging container \"${container_title}\" using docker debug\n"

    docker debug "${container_id}"
  else
    sx::log::fatal 'No debug tool available (install cdebug or use Docker Desktop for docker debug)'
  fi

  exit "${?}"
}
