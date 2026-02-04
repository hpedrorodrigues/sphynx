#!/usr/bin/env bash

function sx::eg::dashboard_targets() {
  local -r print_header="${1:-false}"

  local -r header='TARGET'
  local -r result='envoy-gateway
envoy-proxy'

  if ${print_header}; then
    echo -e "${header}\n${result}"
  else
    echo -e "${result}"
  fi
}

function sx::eg::dashboard() {
  sx::eg::check_requirements

  local -r target="${1:-}"
  local -r query="${2:-}"
  local -r namespace="${3:-}"
  local -r all_namespaces="${4:-false}"
  local -r port="${5:-}"

  if [ -n "${target}" ]; then
    case "${target}" in
      envoy-gateway)
        sx::eg_command::dashboard_envoy_gateway "${namespace}" "${port}"
        ;;
      envoy-proxy)
        sx::eg::dashboard_envoy_proxy "${query}" "${namespace}" "${all_namespaces}" "${port}"
        ;;
      *)
        sx::log::fatal "Unknown dashboard target: ${target}. Supported: envoy-gateway, envoy-proxy"
        ;;
    esac
  elif sx::os::is_command_available 'fzf'; then
    local -r options="$(sx::eg::dashboard_targets true)"

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf --header-lines 1 ${SX_FZF_ARGS})"

    if [ -n "${selected}" ]; then
      sx::eg::dashboard "${selected}" "${query}" "${namespace}" "${all_namespaces}" "${port}"
    fi
  else
    export PS3=$'\n''Please, choose the dashboard target: '$'\n'

    local options
    readarray -t options < <(sx::eg::dashboard_targets)

    select selected in "${options[@]}"; do
      sx::eg::dashboard "${selected}" "${query}" "${namespace}" "${all_namespaces}" "${port}"
      break
    done
  fi
}

function sx::eg::dashboard_envoy_proxy() {
  local -r query="${1:-}"
  local -r namespace="${2:-}"
  local -r all_namespaces="${3:-false}"
  local -r port="${4:-}"

  if sx::os::is_command_available 'fzf'; then
    local options
    readarray -t options < <(
      sx::eg::proxy_pods "${query}" "${namespace}" "${all_namespaces}" true
    )

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No Envoy proxy pods found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(printf '%s\n' "${options[@]}" | fzf --header-lines 1 ${SX_FZF_ARGS})"

    if [ -n "${selected}" ]; then
      local -r ns="$(echo "${selected}" | awk '{ print $1 }')"
      local -r name="$(echo "${selected}" | awk '{ print $2 }')"

      sx::eg_command::dashboard_envoy_proxy "${ns}" "${name}" "${port}"
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

      sx::eg_command::dashboard_envoy_proxy "${ns}" "${name}" "${port}"
      break
    done
  fi
}

function sx::eg_command::dashboard_envoy_gateway() {
  local -r namespace="${1:-}"
  local -r port="${2:-}"

  local flags=''
  if [ -n "${namespace}" ]; then
    flags+=" --namespace ${namespace}"
  fi
  if [ -n "${port}" ]; then
    flags+=" --port ${port}"
  fi

  sx::log::info "Opening Envoy Gateway admin dashboard\n"

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  sx::eg::cli experimental dashboard envoy-gateway ${flags}
}

function sx::eg_command::dashboard_envoy_proxy() {
  local -r ns="${1}"
  local -r name="${2}"
  local -r port="${3:-}"

  local flags=''
  if [ -n "${port}" ]; then
    flags+=" --port ${port}"
  fi

  sx::log::info "Opening Envoy proxy dashboard for pod \"${ns}/${name}\"\n"

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  sx::eg::cli experimental dashboard envoy-proxy "${name}" \
    --namespace "${ns}" \
    ${flags}
}
