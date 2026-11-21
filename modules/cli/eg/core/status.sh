#!/usr/bin/env bash

function sx::eg::status() {
  sx::eg::check_requirements
  sx::k8s::ensure_api_access

  local -r kind="${1:-}"
  local -r namespace="${2:-}"
  local -r all_namespaces="${3:-false}"
  local -r verbose="${4:-false}"

  if [ -n "${kind}" ]; then
    sx::eg_command::status "${kind}" "${namespace}" "${all_namespaces}" "${verbose}"
  else
    local -r options="$(sx::eg::resource_kinds true true)"

    local -r selected="$(sx::select_one 'Please, choose the resource kind' 1 <<<"${options}")"

    if [ -n "${selected}" ]; then
      sx::eg_command::status "${selected}" "${namespace}" "${all_namespaces}" "${verbose}"
    fi
  fi
}

function sx::eg_command::status() {
  local -r kind="${1}"
  local -r namespace="${2:-}"
  local -r all_namespaces="${3:-false}"
  local -r verbose="${4:-false}"

  local flags=''
  if ${all_namespaces}; then
    flags+=' --all-namespaces'
  elif [ -n "${namespace}" ]; then
    flags+=" --namespace ${namespace}"
  else
    flags+=" --namespace $(sx::k8s::current_namespace)"
  fi

  if ${verbose}; then
    flags+=' --verbose'
  fi

  sx::log::info "Fetching status for ${kind} resources\n"

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  sx::eg::cli experimental status "${kind}" ${flags}
}
