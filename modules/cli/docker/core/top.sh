#!/usr/bin/env bash

function sx::docker::top() {
  sx::docker::check_requirements

  local -r options="$(sx::docker::running_containers)"

  if [ -z "${options}" ]; then
    sx::log::fatal 'No running containers found'
  fi

  local -r selected="$(sx::select_one 'Type the respective container number' <<<"${options}")"

  [ -n "${selected}" ] \
    && sx::docker_command::top "$(echo "${selected}" | awk '{ print $1 }')"
}

function sx::docker_command::top() {
  local -r container_id="${1}"

  docker top "${container_id}"
}
