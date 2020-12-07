#!/usr/bin/env bash

function sx::docker::inspect() {
  sx::docker::check_requirements

  if sx::os::is_command_available 'fzf'; then
    local -r options="$(sx::docker::list_resources)"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No objects found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    echo -e "${options}" \
      | fzf --multi ${SX_FZF_ARGS} \
      | while read -r selected; do
        [ -n "${selected}" ] \
          && sx::docker_command::inspect "$(echo "${selected}" | awk '{ print $2 }')"
      done
  else
    export PS3=$'\n''Type the respective resource number: '$'\n'

    local options
    readarray -t options < <(sx::docker::list_resources)

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No objects found'
    fi

    select selected in "${options[@]}"; do
      sx::docker_command::inspect "$(echo "${selected}" | awk '{ print $2 }')"
      break
    done
  fi
}

function sx::docker_command::inspect() {
  local -r resource_id="${1}"

  docker inspect "${resource_id}"
}
