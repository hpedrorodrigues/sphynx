#!/usr/bin/env bash

function sx::flux::suspend::list() {
  sx::flux::check_requirements

  local -r query="${1:-}"
  local -r namespace="${2:-}"
  local -r all_namespaces="${3:-false}"

  local -r resources="$(sx::flux::suspended_resources "${query}" "${namespace}" "${all_namespaces}")"

  if [ -z "${resources}" ]; then
    sx::log::fatal 'No suspended resources found'
  fi

  sx::log::info "${resources}"
}

function sx::flux::suspend() {
  sx::flux::check_requirements

  local -r query="${1:-}"
  local -r namespace="${2:-}"
  local -r all_namespaces="${3:-false}"
  local -r kind="${4:-}"
  local -r name="${5:-}"

  if [ -n "${kind}" ] && [ -n "${name}" ]; then
    local -r resolved_kind="$(echo "${kind}" | sx::string::lowercase)"

    sx::flux_command::suspend "${namespace}" "${resolved_kind}" "${name}"
  elif sx::os::is_command_available 'fzf'; then
    local -r options="$(
      sx::flux::resources "${query}" "${namespace}" "${all_namespaces}"
    )"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No resources found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf ${SX_FZF_ARGS})"

    if [ -n "${selected}" ]; then
      local -r selected_ns="$(echo "${selected}" | awk '{ print $1 }')"
      local -r selected_kind="$(echo "${selected}" | awk '{ print $2 }')"
      local -r selected_name="$(echo "${selected}" | awk '{ print $3 }')"

      sx::flux_command::suspend "${selected_ns}" "${selected_kind}" "${selected_name}"
    fi
  else
    export PS3=$'\n''Please, choose the resource: '$'\n'

    local options
    readarray -t options < <(
      sx::flux::resources "${query}" "${namespace}" "${all_namespaces}"
    )

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No resources found'
    fi

    select selected in "${options[@]}"; do
      local -r selected_ns="$(echo "${selected}" | awk '{ print $1 }')"
      local -r selected_kind="$(echo "${selected}" | awk '{ print $2 }')"
      local -r selected_name="$(echo "${selected}" | awk '{ print $3 }')"

      sx::flux_command::suspend "${selected_ns}" "${selected_kind}" "${selected_name}"
      break
    done
  fi
}

function sx::flux_command::suspend() {
  local -r ns="${1}"
  local -r kind="${2}"
  local -r name="${3}"

  local -r flux_type="$(sx::flux::kind_to_type "${kind}")"

  local ns_flag=''
  if [ -n "${ns}" ]; then
    ns_flag="--namespace ${ns}"
  fi

  sx::log::info "Suspending ${kind} \"${ns:-default}/${name}\"\n"

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  sx::flux::cli suspend ${flux_type} "${name}" ${ns_flag}
}
