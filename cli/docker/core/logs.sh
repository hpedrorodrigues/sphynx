#!/usr/bin/env bash

function sx::docker::logs() {
  sx::docker::check_requirements

  if sx::os::is_command_available 'fzf'; then
    local -r containers="$(sx::docker::all_containers)"

    if [ -z "${containers}" ]; then
      sx::log::fatal 'No containers found'
    fi

    local -r row="$(echo -e "${containers}" | fzf)"
  else
    export PS3=$'\n''Type the respective container number: '$'\n'

    local containers
    readarray -t containers < <(sx::docker::all_containers)

    if [ "${#containers[@]}" -eq 0 ]; then
      sx::log::fatal 'No containers found'
    fi

    select option in "${containers[@]}"; do
      local -r row="${option}"
      break
    done
  fi

  [ -n "${row}" ] \
    && sx::docker_command::logs "$(echo "${row}" | awk '{ print $1 }')"
}

function sx::docker_command::logs() {
  local -r container_id="${1}"

  docker logs --tail 1000 --follow "${container_id}"
}
