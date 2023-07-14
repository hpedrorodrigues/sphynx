#!/usr/bin/env bash

function sx::nerdctl::delete() {
  sx::nerdctl::check_requirements

  if sx::os::is_command_available 'fzf'; then
    local -r options="$(sx::nerdctl::list_resources)"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No objects found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf ${SX_FZF_ARGS})"

    if [ -n "${selected}" ]; then
      local -r type="$(echo "${selected}" | awk '{ print $1 }')"
      local -r id="$(echo "${selected}" | awk '{ print $2 }')"
      local -r description="$(echo "${selected}" | awk '{ print $3 }')"

      sx::nerdctl_command::delete "${type}" "${id}" "${description}"
    fi
  else
    export PS3=$'\n''Type the respective resource number: '$'\n'

    local options
    readarray -t options < <(sx::nerdctl::list_resources)

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No objects found'
    fi

    select selected in "${options[@]}"; do
      local -r type="$(echo "${selected}" | awk '{ print $1 }')"
      local -r id="$(echo "${selected}" | awk '{ print $2 }')"
      local -r description="$(echo "${selected}" | awk '{ print $3 }')"

      sx::nerdctl_command::delete "${type}" "${id}" "${description}"
      break
    done
  fi
}

function sx::nerdctl_command::delete() {
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
        nerdctl rm --force "${resource_id}"
        ;;
      'image')
        nerdctl rmi --force "${resource_id}"
        ;;
      'volume')
        nerdctl volume rm --force "${resource_id}"
        ;;
      'network')
        nerdctl network rm "${resource_id}"
        ;;
      *)
        sx::log::fatal "Unsupported resource type (${resource_type})"
        ;;
    esac
  fi
}
