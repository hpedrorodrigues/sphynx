#!/usr/bin/env bash

function sx::docker::delete() {
  sx::docker::check_requirements

  if sx::os::is_command_available 'fzf'; then
    local -r resources="$(sx::docker::list_resources)"

    if [ -z "${resources}" ]; then
      sx::log::fatal 'No objects found'
    fi

    local -r row="$(echo -e "${resources}" | fzf)"

    if [ -z "${row}" ]; then
      # User does not select any option
      exit 0
    fi

    local -r type="$(echo "${row}" | awk '{ print $1 }')"
    local -r id="$(echo "${row}" | awk '{ print $2 }')"
    local -r description="$(echo "${row}" | awk '{ print $3 }')"

    sx::docker_command::delete "${type}" "${id}" "${description}"
  else
    export PS3=$'\n''Type the respective resource number: '$'\n'

    local resources
    readarray -t resources < <(sx::docker::list_resources)

    if [ "${#resources[@]}" -eq 0 ]; then
      sx::log::fatal 'No objects found'
    fi

    local type=''
    local id=''
    local description=''

    select resource in "${resources[@]}"; do
      type="$(echo "${resource}" | awk '{ print $1 }')"
      id="$(echo "${resource}" | awk '{ print $2 }')"
      description="$(echo "${resource}" | awk '{ print $3 }')"

      sx::docker_command::delete "${type}" "${id}" "${description}"
      break
    done
  fi
}

function sx::docker_command::delete() {
  local -r resource_type="${1}"
  local -r resource_id="${2}"
  local -r description="${3}"

  if ${SX_CONFIRMATION_REQUIRED:-true}; then
    sx::log::info "Do you really want to delete the ${resource_type} [${description} - ${resource_id}]? Be careful. [y/n]"
    read -e -r confirmation
  fi

  if ! "${SX_CONFIRMATION_REQUIRED:-true}" \
    || [ "${confirmation:-'n'}" = 'y' ] \
    || [ "${confirmation:-'n'}" = 'yes' ]; then
    case "${resource_type}" in
      'container')
        docker rm --force "${resource_id}"
        ;;
      'image')
        docker rmi --force "${resource_id}"
        ;;
      'volume')
        docker volume rm --force "${resource_id}"
        ;;
      'network')
        docker network rm "${resource_id}"
        ;;
      *)
        sx::log::fatal "Unsupported resource type (${resource_type})"
        ;;
    esac
  fi
}
