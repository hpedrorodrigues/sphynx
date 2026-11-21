#!/usr/bin/env bash

function sx::docker::exec() {
  sx::docker::check_requirements

  local -r container_id="${1:-}"

  if [ -n "${container_id}" ]; then
    if sx::docker::has_container "${container_id}"; then
      sx::docker_command::exec \
        "${container_id}" \
        "$(sx::docker::container_name "${container_id}")"
    else
      sx::log::fatal 'No such container'
    fi
  else
    local -r options="$(sx::docker::running_containers)"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No running containers found'
    fi

    local -r selected="$(sx::select_one 'Type the respective container number' <<<"${options}")"
  fi

  if [ -n "${selected}" ]; then
    local -r id="$(echo "${selected}" | awk '{ print $1 }')"
    local -r name="$(echo "${selected}" | awk '{ print $2 }')"

    sx::docker_command::exec "${id}" "${name}"
  fi
}

function sx::docker_command::exec() {
  local -r container_id="${1}"
  local -r container_name="${2}"

  local -r container_title="${container_name}/${container_id}"

  local -r shells=(
    '/bin/bash'
    '/bin/sh'
  )

  for shell in "${shells[@]}"; do
    if docker exec "${container_id}" "${shell}" -c 'exit' &>/dev/null; then
      sx::log::info "Now you can execute commands in container \"${container_title}\" using \"${shell}\"\n"

      docker exec \
        --interactive \
        --tty \
        "${container_id}" \
        "${shell}" -c "PS1='${SX_PS1}' exec ${shell}"

      exit "${?}"
    fi
  done

  sx::log::fatal "No shell available to run in container \"${container_title}\""
}
