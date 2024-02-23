#!/usr/bin/env bash

function sx::k8s::debug() {
  sx::k8s::check_requirements
  sx::k8s::ensure_api_access

  local -r query="${1:-}"
  local -r namespace="${2:-}"
  local -r pod="${3:-}"
  local -r container="${4:-}"
  local -r image="${5:-}"
  local -r all_namespaces="${6:-false}"

  if [ -n "${namespace}" ] && [ -n "${pod}" ] && [ -n "${container}" ] && [ -n "${image}" ]; then
    sx::k8s_command::debug "${namespace}" "${pod}" "${container}" "${image}"
  elif sx::os::is_command_available 'fzf'; then
    local -r options="$(
      sx::k8s::running_pods "${query}" "${namespace}" "${all_namespaces}" true
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

      sx::k8s_command::debug "${ns}" "${name}" "${container_name}" "${image}"
    fi
  else
    export PS3=$'\n''Please, choose the pod: '$'\n'

    local options
    readarray -t options < <(
      sx::k8s::running_pods "${query}" "${namespace}" "${all_namespaces}"
    )

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No running pods found'
    fi

    select selected in "${options[@]}"; do
      local -r ns="$(echo "${selected}" | awk '{ print $1 }')"
      local -r name="$(echo "${selected}" | awk '{ print $2 }')"
      local -r container_name="$(echo "${selected}" | awk '{ print $3 }')"

      sx::k8s_command::debug "${ns}" "${name}" "${container_name}" "${image}"
      break
    done
  fi
}

function sx::k8s_command::debug() {
  local -r ns="${1}"
  local -r name="${2}"
  local -r container="${3}"
  local -r image="${4}"

  local -r shells=(
    '/bin/bash'
    '/bin/sh'
  )

  for shell in "${shells[@]}"; do
    if sx::k8s::cli exec -n "${ns}" "${name}" -c "${container}" -- "${shell}" -c 'exit' &>/dev/null; then
      sx::log::info "Now you can execute commands in \"${name}/${container}\" using image \"${image}\" with \"${shell}\"\n"

      sx::k8s::cli debug "${name}" \
        --stdin \
        --tty \
        --namespace "${ns}" \
        --target "${container}" \
        --image "${image}" \
        --quiet \
        -- "${shell}" -c "PS1='${SX_PS1}' exec ${shell}"

      exit "${?}"
    fi
  done

  sx::log::fatal "No shell available to run in \"${name}/${image}\""
}
