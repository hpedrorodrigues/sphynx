#!/usr/bin/env bash

function sx::k8s::get() {
  sx::k8s::check_requirements

  local -r query="${1:-}"
  local -r namespace="${2:-}"
  local -r all_namespaces="${3:-false}"
  local -r format="${4}"
  local -r no_color="${5}"

  if sx::os::is_command_available 'fzf'; then
    local -r options="$(
      sx::k8s::resources "${query}" "${namespace}" "${all_namespaces}"
    )"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No resources found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf ${SX_FZF_ARGS})"

    if [ -n "${selected}" ]; then
      local -r ns="$(echo "${selected}" | awk '{ print $1 }')"
      local -r kind="$(echo "${selected}" | awk '{ print $2 }')"
      local -r name="$(echo "${selected}" | awk '{ print $3 }')"

      sx::k8s_command::get "${ns}" "${kind}" "${name}" "${format}" "${no_color}"
    fi
  else
    export PS3=$'\n''Please, choose the resource: '$'\n'

    local options
    mapfile -t options < <(
      sx::k8s::resources "${query}" "${namespace}" "${all_namespaces}"
    )

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No resources found'
    fi

    select selected in "${options[@]}"; do
      local -r ns="$(echo "${selected}" | awk '{ print $1 }')"
      local -r kind="$(echo "${selected}" | awk '{ print $2 }')"
      local -r name="$(echo "${selected}" | awk '{ print $3 }')"

      sx::k8s_command::get "${ns}" "${kind}" "${name}" "${format}" "${no_color}"
      break
    done
  fi
}

function sx::k8s_command::get() {
  local -r ns="${1:-}"
  local -r kind="${2:-}"
  local -r name="${3:-}"
  local -r format="${4:-}"
  local -r no_color="${5:-}"

  if ${no_color}; then
    local -r colorizer='cat'
  elif [ "${format}" = 'json' ]; then
    local -r colorizer='sx::json'
  elif [ "${format}" = 'yaml' ]; then
    local -r colorizer='sx::yaml'
  else
    local -r colorizer='cat'
  fi

  sx::log::info "Retrieving information from ${kind} \"${ns}/${name}\"\n"

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  sx::k8s::cli get "${kind}" "${name}" \
    --namespace "${ns}" \
    --output "${format}" | ${colorizer}
}
