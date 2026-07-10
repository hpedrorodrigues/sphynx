#!/usr/bin/env bash

function sx::gcloud::cluster() {
  sx::gcloud::check_requirements

  local -r query="${1:-}"
  local -r list_clusters="${2:-false}"
  local -r project="${3:-}"

  if ${list_clusters}; then
    local -r clusters="$(sx::gcloud_command::cluster::search "${query}" "${project}")"

    if [ -z "${clusters}" ]; then
      sx::log::fatal 'No clusters found'
    fi

    sx::log::info "${clusters}"
  elif sx::os::is_command_available 'fzf'; then
    local -r options="$(sx::gcloud_command::cluster::search "${query}" "${project}")"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No clusters found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf ${SX_FZF_ARGS})"

    if [ -n "${selected}" ]; then
      local -r name="$(echo "${selected}" | awk '{ print $1 }')"
      local -r location="$(echo "${selected}" | awk '{ print $2 }')"

      sx::gcloud_command::cluster::get_credentials "${name}" "${location}" "${project}"
    fi
  else
    export PS3=$'\n''Please, choose the cluster: '$'\n'

    local options
    readarray -t options < <(sx::gcloud_command::cluster::search "${query}" "${project}")

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No clusters found'
    fi

    select selected in "${options[@]}"; do
      if [ -z "${selected}" ]; then
        sx::log::err "Invalid option \"${REPLY}\". Please, type the number of the desired option."
        continue
      fi

      local -r name="$(echo "${selected}" | awk '{ print $1 }')"
      local -r location="$(echo "${selected}" | awk '{ print $2 }')"

      sx::gcloud_command::cluster::get_credentials "${name}" "${location}" "${project}"
      break
    done
  fi
}

function sx::gcloud_command::cluster::search() {
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
  sx::gcloud::cli container clusters list \
    --format='value[separator=","](name, location, status)' \
    ${flags} \
    | column -t -s ',' \
    | grep -E "${selector}" 2>/dev/null
}

function sx::gcloud_command::cluster::get_credentials() {
  local -r name="${1}"
  local -r location="${2}"
  local -r project="${3:-}"

  local flags=''
  if [ -n "${project}" ]; then
    flags=" --project ${project}"
  fi

  sx::log::info "Fetching credentials for cluster \"${name}\" (${location})\n"

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  sx::gcloud::cli container clusters get-credentials "${name}" --location "${location}" ${flags}
}
