#!/usr/bin/env bash

function sx::docker::inspect() {
  sx::docker::check_requirements

  if sx::os::is_command_available 'fzf'; then
    local -r resources="$(sx::docker::list_resources)"

    if [ -z "${resources}" ]; then
      sx::log::fatal 'No objects found'
    fi

    echo -e "${resources}" \
      | fzf --multi \
      | while read -r resource; do
        [ -n "${resource}" ] \
          && sx::docker_command::inspect "$(echo "${resource}" | awk '{ print $2 }')"
      done
  else
    export PS3=$'\n''Type the respective resource number: '$'\n'

    local resources
    readarray -t resources < <(sx::docker::list_resources)

    if [ "${#resources[@]}" -eq 0 ]; then
      sx::log::fatal 'No objects found'
    fi

    select resource in "${resources[@]}"; do
      sx::docker_command::inspect "$(echo "${resource}" | awk '{ print $2 }')"
      break
    done
  fi
}

function sx::docker_command::inspect() {
  local -r resource_id="${1}"

  docker inspect "${resource_id}"
}
