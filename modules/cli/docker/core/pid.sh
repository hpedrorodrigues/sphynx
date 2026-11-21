#!/usr/bin/env bash

function sx::docker::pid() {
  sx::docker::check_requirements

  local -r options="$(sx::docker::running_containers)"

  if [ -z "${options}" ]; then
    sx::log::fatal 'No running containers found'
  fi

  local -r selected="$(sx::select_one 'Type the respective container number' <<<"${options}")"

  [ -n "${selected}" ] \
    && sx::docker_command::pid "$(echo "${selected}" | awk '{ print $1 }')"
}

function sx::docker_command::pid() {
  local -r container_id="${1}"

  docker inspect --format '{{.State.Pid}}' "${container_id}"
}
