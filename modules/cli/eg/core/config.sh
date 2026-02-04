#!/usr/bin/env bash

function sx::eg::config() {
  sx::eg::check_requirements

  local -r query="${1:-}"
  local -r namespace="${2:-}"
  local -r all_namespaces="${3:-false}"
  local -r output="${4:-yaml}"
  local -r resource="${5:-all}"

  if sx::os::is_command_available 'fzf'; then
    local -r options="$(
      sx::eg::proxy_pods "${query}" "${namespace}" "${all_namespaces}" true
    )"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No Envoy proxy pods found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf --header-lines 1 ${SX_FZF_ARGS})"

    if [ -n "${selected}" ]; then
      local -r ns="$(echo "${selected}" | awk '{ print $1 }')"
      local -r name="$(echo "${selected}" | awk '{ print $2 }')"

      sx::eg_command::config "${ns}" "${name}" "${output}" "${resource}"
    fi
  else
    export PS3=$'\n''Please, choose the pod: '$'\n'

    local options
    readarray -t options < <(
      sx::eg::proxy_pods "${query}" "${namespace}" "${all_namespaces}"
    )

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No Envoy proxy pods found'
    fi

    select selected in "${options[@]}"; do
      local -r ns="$(echo "${selected}" | awk '{ print $1 }')"
      local -r name="$(echo "${selected}" | awk '{ print $2 }')"

      sx::eg_command::config "${ns}" "${name}" "${output}" "${resource}"
      break
    done
  fi
}

function sx::eg_command::config() {
  local -r ns="${1}"
  local -r name="${2}"
  local -r output="${3}"
  local -r resource="${4}"

  sx::log::info "Fetching Envoy config (${resource}) from pod \"${ns}/${name}\"\n"

  sx::eg::cli config envoy-proxy "${resource}" "${name}" \
    --namespace "${ns}" \
    --output "${output}"
}
