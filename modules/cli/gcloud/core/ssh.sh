#!/usr/bin/env bash

function sx::gcloud::ssh() {
  sx::gcloud::check_requirements

  local -r query="${1:-}"
  local -r list_instances="${2:-false}"
  local -r project="${3:-}"
  local -r iap="${4:-false}"

  if ${list_instances}; then
    local -r instances="$(sx::gcloud_command::ssh::search "${query}" "${project}")"

    if [ -z "${instances}" ]; then
      sx::log::fatal 'No instances found'
    fi

    sx::log::info "${instances}"
  elif sx::os::is_command_available 'fzf'; then
    local -r options="$(sx::gcloud_command::ssh::search "${query}" "${project}")"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No instances found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf ${SX_FZF_ARGS})"

    if [ -n "${selected}" ]; then
      local -r name="$(echo "${selected}" | awk '{ print $1 }')"
      local -r zone="$(echo "${selected}" | awk '{ print $2 }')"

      sx::gcloud_command::ssh::connect "${name}" "${zone}" "${project}" "${iap}"
    fi
  else
    export PS3=$'\n''Please, choose the instance: '$'\n'

    local options
    readarray -t options < <(sx::gcloud_command::ssh::search "${query}" "${project}")

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No instances found'
    fi

    select selected in "${options[@]}"; do
      if [ -z "${selected}" ]; then
        sx::log::err "Invalid option \"${REPLY}\". Please, type the number of the desired option."
        continue
      fi

      local -r name="$(echo "${selected}" | awk '{ print $1 }')"
      local -r zone="$(echo "${selected}" | awk '{ print $2 }')"

      sx::gcloud_command::ssh::connect "${name}" "${zone}" "${project}" "${iap}"
      break
    done
  fi
}

function sx::gcloud_command::ssh::search() {
  local -r query="${1:-}"
  local -r project="${2:-}"

  local flags=''
  if [ -n "${project}" ]; then
    flags=" --project ${project}"
  fi

  if [ -n "${query}" ]; then
    local -r selector="$(echo "${query}" | sx::string::lowercase)"
  else
    local -r selector='.*'
  fi

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  sx::gcloud::cli compute instances list \
    --format='value[separator=","](name, zone, status)' \
    ${flags} \
    | column -t -s ',' \
    | grep -E "${selector}" 2>/dev/null
}

function sx::gcloud_command::ssh::connect() {
  local -r name="${1}"
  local -r zone="${2}"
  local -r project="${3:-}"
  local -r iap="${4:-false}"

  local flags=''
  if ${iap}; then
    flags+=' --tunnel-through-iap'
  else
    flags+=' --internal-ip'
  fi

  if [ -n "${project}" ]; then
    flags+=" --project ${project}"
  fi

  sx::log::info "Connecting to instance \"${name}\" (${zone})\n"

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  sx::gcloud::cli compute ssh "${name}" --zone "${zone}" ${flags}
}
