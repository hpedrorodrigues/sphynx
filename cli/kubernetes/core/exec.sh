#!/usr/bin/env bash

function sx::k8s::exec() {
  sx::k8s::check_requirements

  local -r query="${1:-}"
  local -r namespace="${2:-}"
  local -r all_namespaces="${3:-false}"

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

      sx::k8s_command::exec "${ns}" "${name}"
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

      sx::k8s_command::exec "${ns}" "${name}"
      break
    done
  fi
}

function sx::k8s_command::exec() {
  local -r ns="${1}"
  local -r pod_id="${2}"

  local -r shells=(
    '/bin/bash'
    '/bin/sh'
  )

  for shell in "${shells[@]}"; do
    if sx::k8s::cli exec --namespace "${ns}" "${pod_id}" -- "${shell}" -c 'exit' &>/dev/null; then
      sx::log::info "Now you can execute commands in pod \"${pod_id}\" using \"${shell}\"."

      sx::k8s::cli exec \
        --stdin \
        --tty \
        --namespace "${ns}" \
        "${pod_id}" -- "${shell}" 2>/dev/null

      exit 0
    fi
  done
}
