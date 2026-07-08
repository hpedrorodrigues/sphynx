#!/usr/bin/env bash

function sx::k8s::prof::check_requirements() {
  if ! sx::os::is_command_available 'kubectl-prof'; then
    sx::log::fatal 'The kubectl plugin "prof" is not installed. For more details, see: https://github.com/josepdcs/kubectl-prof.'
  fi
}

function sx::k8s::prof() {
  sx::k8s::check_requirements
  sx::k8s::prof::check_requirements
  sx::k8s::ensure_api_access

  local -r query="${1:-}"
  local -r selector="${2:-}"
  local -r namespace="${3:-}"
  local -r pod="${4:-}"
  local -r container="${5:-}"
  local -r all_namespaces="${6:-false}"
  local -r extra_flags="${7:-}"

  if [ -n "${namespace}" ] && [ -n "${pod}" ] && [ -n "${container}" ]; then
    sx::k8s_command::prof "${namespace}" "${pod}" "${container}" "${extra_flags}"
  elif sx::os::is_command_available 'fzf'; then
    local -r options="$(
      sx::k8s::running_pods "${query}" "${selector}" "${namespace}" "${all_namespaces}" true
    )"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No running pods found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf --header-lines 1 ${SX_FZF_ARGS})"

    if [ -n "${selected}" ]; then
      local -r ns="$(echo "${selected}" | awk '{ print $1 }')"
      local -r name="$(echo "${selected}" | awk '{ print $2 }')"
      local -r container_name="$(echo "${selected}" | awk '{ print $3 }')"

      sx::k8s_command::prof "${ns}" "${name}" "${container_name}" "${extra_flags}"
    fi
  else
    export PS3=$'\n''Please, choose the pod: '$'\n'

    local options
    readarray -t options < <(
      sx::k8s::running_pods "${query}" "${selector}" "${namespace}" "${all_namespaces}"
    )

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No running pods found'
    fi

    select selected in "${options[@]}"; do
      local -r ns="$(echo "${selected}" | awk '{ print $1 }')"
      local -r name="$(echo "${selected}" | awk '{ print $2 }')"
      local -r container_name="$(echo "${selected}" | awk '{ print $3 }')"

      sx::k8s_command::prof "${ns}" "${name}" "${container_name}" "${extra_flags}"
      break
    done
  fi
}

function sx::k8s_command::prof() {
  local -r ns="${1}"
  local -r name="${2}"
  local -r container="${3}"
  local -r extra_flags="${4:-}"

  sx::log::info "Profiling pod \"${name}/${container}\"...\n"

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  sx::k8s::cli prof "${name}" \
    --namespace "${ns}" \
    --target-container-name "${container}" \
    ${extra_flags}
}
