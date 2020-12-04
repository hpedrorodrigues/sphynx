#!/usr/bin/env bash

function sx::docker::exec() {
  sx::docker::check_requirements

  if sx::os::is_command_available 'fzf'; then
    local -r containers="$(sx::docker::running_containers)"

    if [ -z "${containers}" ]; then
      sx::log::fatal 'No running containers found'
    fi

    local -r row="$(echo -e "${containers}" | fzf)"
  else
    export PS3=$'\n''Type the respective container number: '$'\n'

    local containers
    readarray -t containers < <(sx::docker::running_containers)

    if [ "${#containers[@]}" -eq 0 ]; then
      sx::log::fatal 'No running containers found'
    fi

    select option in "${containers[@]}"; do
      local -r row="${option}"
      break
    done
  fi

  [ -n "${row}" ] \
    && sx::docker_command::exec "$(echo "${row}" | awk '{ print $1 }')"
}

function sx::docker_command::exec() {
  local -r container_id="${1}"

  docker exec -it "${container_id}" sh
}
