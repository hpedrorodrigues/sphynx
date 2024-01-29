#!/usr/bin/env bash

function sx::gcloud::named_configuration() {
  sx::gcloud::check_requirements

  local -r query="${1:-}"
  local -r exact_named_configuration="${2:-}"
  local -r list_named_configurations="${3:-false}"

  if [ -n "${exact_named_configuration}" ]; then
    sx::gcloud::named_configuration::change "${exact_named_configuration}"
  elif ${list_named_configurations}; then
    local -r current_named_configuration="$(sx::gcloud::named_configuration::current)"

    while IFS='' read -r named_configuration; do
      if echo "${named_configuration}" | grep -q "${current_named_configuration}" 2>/dev/null; then
        sx::color::current_item::echo "${named_configuration}"
      else
        echo "${named_configuration}"
      fi
    done < <(sx::gcloud::named_configuration::list)
  elif sx::os::is_command_available 'fzf'; then
    local -r options="$(sx::gcloud_command::named_configuration::search "${query}")"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No resources found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf ${SX_FZF_ARGS})"

    [ -n "${selected}" ] && sx::gcloud::named_configuration::change "${selected}"
  else
    export PS3=$'\n''Please, choose the resource: '$'\n'

    local options
    readarray -t options < <(sx::gcloud_command::named_configuration::search "${query}")

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No resources found'
    fi

    select selected in "${options[@]}"; do
      sx::gcloud::named_configuration::change "${selected}"
      break
    done
  fi
}

function sx::gcloud_command::named_configuration::search() {
  local -r query="${1:-}"

  if [ -n "${query}" ]; then
    local -r selector="$(echo "${query}" | sx::string::lowercase)"
  else
    local -r selector='.*'
  fi

  local -r named_configurations="$(sx::gcloud::named_configuration::list | grep -E "${selector}")"
  local -r current_named_configuration="$(sx::gcloud::named_configuration::current)"

  # shellcheck disable=SC2068  # Double quote array expansions
  for named_configuration in ${named_configurations[@]}; do
    if [ "${current_named_configuration}" = "${named_configuration}" ]; then
      sx::color::current_item::echo "${named_configuration}"
    else
      echo "${named_configuration}"
    fi
  done
}
