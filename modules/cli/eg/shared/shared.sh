#!/usr/bin/env bash

export SX_ENVOY_GATEWAY_DEFAULT_RESOURCES='GatewayClass,Gateway,HTTPRoute,GRPCRoute,TCPRoute,UDPRoute,TLSRoute,BackendTLSPolicy,BackendTrafficPolicy,ClientTrafficPolicy,SecurityPolicy,EnvoyPatchPolicy,EnvoyExtensionPolicy'
export SX_ENVOY_GATEWAY_RESOURCES="${SX_ENVOY_GATEWAY_RESOURCES:-${SX_ENVOY_GATEWAY_DEFAULT_RESOURCES}}"

export SX_EGCTL="${SX_EGCTL:-egctl}"

function sx::eg::check_requirements() {
  sx::require_supported_os
  sx::require 'egctl'
  sx::require 'kubectl'
}

function sx::eg::cli() {
  ${SX_EGCTL} "${@}"
}

function sx::eg::resource_kinds() {
  local -r print_header="${1:-false}"
  local -r include_all="${2:-false}"

  local -r header='KIND'
  local -r resources="$(echo "${SX_ENVOY_GATEWAY_RESOURCES}" | tr ',' '\n')"

  local result
  if ${include_all}; then
    result="all\n${resources}"
  else
    result="${resources}"
  fi

  if ${print_header}; then
    echo -e "${header}\n${result}"
  else
    echo -e "${result}"
  fi
}

function sx::eg::proxy_pods() {
  local -r query="${1:-}"
  local -r namespace="${2:-}"
  local -r all_namespaces="${3:-false}"
  local -r print_header="${4:-false}"
  local -r context="${5:-}"

  local flags=''
  if ${all_namespaces}; then
    flags='--all-namespaces'
  elif [ -n "${namespace}" ]; then
    flags="--namespace ${namespace}"
  else
    flags="--namespace $(sx::k8s::current_namespace "${context}")"
  fi

  local -r context_flags="$(sx::k8s::context_flags "${context}")"

  local -r selector="${query:-.*}"

  local -r header='NAMESPACE,NAME,GATEWAY'

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  local -r result="$(
    sx::k8s::cli ${context_flags} get pods \
      ${flags} \
      --selector gateway.envoyproxy.io/owning-gateway-name \
      --output custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,GATEWAY:.metadata.labels.gateway\\.envoyproxy\\.io/owning-gateway-name \
      --no-headers 2>/dev/null \
      | grep -E "${selector}" 2>/dev/null
  )"

  if [ -z "${result}" ]; then
    echo
  elif ${print_header}; then
    echo -e "${header}\n${result}" | column -t -s ','
  else
    echo -e "${result}"
  fi
}
