#!/usr/bin/env bash

function sx::k8s::logs() {
  sx::k8s::check_requirements

  local -r query="${1:-}"
  local -r namespace="${2:-}"
  local -r all_namespaces="${3:-false}"
  local -r previous_log="${4:-false}"

  if sx::os::is_command_available 'fzf'; then
    local -r options="$(
      sx::k8s::running_pods "${query}" "${namespace}" "${all_namespaces}"
    )"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No running pods found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf ${SX_FZF_ARGS})"

    if [ -n "${selected}" ]; then
      local -r ns="$(echo "${selected}" | awk '{ print $1 }')"
      local -r name="$(echo "${selected}" | awk '{ print $2 }')"
      local -r container="$(echo "${selected}" | awk '{ print $3 }')"

      sx::k8s_command::logs "${ns}" "${name}" "${container}" "${previous_log}"
    fi
  else
    export PS3=$'\n''Please, choose the pod: '$'\n'

    local options
    mapfile -t options < <(
      sx::k8s::running_pods "${query}" "${namespace}" "${all_namespaces}"
    )

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No running pods found'
    fi

    select selected in "${options[@]}"; do
      local -r ns="$(echo "${selected}" | awk '{ print $1 }')"
      local -r name="$(echo "${selected}" | awk '{ print $2 }')"
      local -r container="$(echo "${selected}" | awk '{ print $3 }')"

      sx::k8s_command::logs "${ns}" "${name}" "${container}" "${previous_log}"
      break
    done
  fi
}

function sx::k8s_command::logs() {
  local -r ns="${1}"
  local -r name="${2}"
  local -r container="${3}"
  local -r previous_log="${4}"

  local flags=''
  if ${previous_log}; then
    flags+=' --previous'
  fi

  sx::log::info "Tailing logs from pod \"${name}/${container}\"\n"

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  sx::k8s::cli logs "${name}" \
    --namespace "${ns}" \
    --container "${container}" \
    --follow \
    ${flags}
}
