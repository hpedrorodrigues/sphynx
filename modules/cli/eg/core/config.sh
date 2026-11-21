#!/usr/bin/env bash

function sx::eg::config() {
  sx::eg::check_requirements

  local -r query="${1:-}"
  local -r namespace="${2:-}"
  local -r all_namespaces="${3:-false}"
  local -r output="${4:-yaml}"
  local -r resource="${5:-all}"
  local -r context="${6:-$(sx::k8s::current_context)}"

  sx::k8s::validate_context "${context}"
  sx::k8s::ensure_api_access "${context}"

  local -r options="$(
    sx::eg::proxy_pods "${query}" "${namespace}" "${all_namespaces}" true "${context}"
  )"

  if [ -z "${options}" ]; then
    sx::log::fatal 'No Envoy proxy pods found'
  fi

  local -r selected="$(sx::select_one 'Please, choose the pod' 1 <<<"${options}")"

  if [ -n "${selected}" ]; then
    local -r ns="$(echo "${selected}" | awk '{ print $1 }')"
    local -r name="$(echo "${selected}" | awk '{ print $2 }')"

    sx::eg_command::config "${ns}" "${name}" "${output}" "${resource}" "${context}"
  fi
}

function sx::eg_command::config() {
  local -r ns="${1}"
  local -r name="${2}"
  local -r output="${3}"
  local -r resource="${4}"
  local -r context="${5:-}"

  local -r context_flags="$(sx::k8s::context_flags "${context}")"

  sx::log::info "Fetching Envoy config (${resource}) from pod \"${ns}/${name}\"\n"

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  sx::eg::cli config envoy-proxy "${resource}" "${name}" \
    --namespace "${ns}" \
    --output "${output}" \
    ${context_flags}
}
