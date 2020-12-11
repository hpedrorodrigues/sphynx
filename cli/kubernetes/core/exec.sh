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
      local -r container="$(echo "${selected}" | awk '{ print $3 }')"

      sx::k8s_command::exec "${ns}" "${name}" "${container}"
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

      sx::k8s_command::exec "${ns}" "${name}" "${container}"
      break
    done
  fi
}

function sx::k8s_command::exec() {
  local -r ns="${1}"
  local -r name="${2}"
  local -r container="${3}"

  local -r shells=(
    '/bin/bash'
    '/bin/sh'
  )

  for shell in "${shells[@]}"; do
    if sx::k8s::cli exec -n "${ns}" "${name}" -c "${container}" -- "${shell}" -c 'exit' &>/dev/null; then
      sx::log::info "Now you can execute commands in pod \"${name}/${container}\" using \"${shell}\"\n"

      local -r ps1='\u@\h:\w '

      sx::k8s::cli exec "${name}" \
        --stdin \
        --tty \
        --namespace "${ns}" \
        --container "${container}" \
        -- "${shell}" -c "PS1='${SX_KUBERNETES_PS1:-${ps1}}' exec ${shell}"

      exit 0
    fi
  done

  sx::log::fatal "No shell available to run in pod \"${name}/${container}\""
}
