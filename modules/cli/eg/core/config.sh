#!/usr/bin/env bash

function sx::eg::config() {
  sx::eg::check_requirements
  sx::k8s::ensure_api_access

  local -r query="${1:-}"
  local -r namespace="${2:-}"
  local -r all_namespaces="${3:-false}"
  local -r output="${4:-yaml}"
  local -r resource="${5:-all}"

  local -r options="$(
    sx::eg::proxy_pods "${query}" "${namespace}" "${all_namespaces}" true
  )"

  if [ -z "${options}" ]; then
    sx::log::fatal 'No Envoy proxy pods found'
  fi

  local -r selected="$(sx::select_one 'Please, choose the pod' 1 <<<"${options}")"

  if [ -n "${selected}" ]; then
    local -r ns="$(echo "${selected}" | awk '{ print $1 }')"
    local -r name="$(echo "${selected}" | awk '{ print $2 }')"

    sx::eg_command::config "${ns}" "${name}" "${output}" "${resource}"
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
