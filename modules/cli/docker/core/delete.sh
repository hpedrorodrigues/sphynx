#!/usr/bin/env bash

function sx::docker::delete() {
  sx::docker::check_requirements

  local -r options="$(sx::docker::list_resources)"

  if [ -z "${options}" ]; then
    sx::log::fatal 'No objects found'
  fi

  local -r selected="$(sx::select_one 'Type the respective resource number' <<<"${options}")"

  if [ -n "${selected}" ]; then
    local -r type="$(echo "${selected}" | awk '{ print $1 }')"
    local -r id="$(echo "${selected}" | awk '{ print $2 }')"
    local -r description="$(echo "${selected}" | awk '{ print $3 }')"

    sx::docker_command::delete "${type}" "${id}" "${description}"
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
      'build')
        docker buildx history rm "${resource_id}"
        ;;
      *)
        sx::log::fatal "Unsupported resource type (${resource_type})"
        ;;
    esac
  fi
}
