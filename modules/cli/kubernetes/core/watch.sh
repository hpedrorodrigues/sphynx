#!/usr/bin/env bash

function sx::k8s::watch::resources() {
  sx::k8s::check_requirements
  sx::k8s::ensure_api_access

  local -r resources="${1:-pods}"
  local -r namespace="${2:-$(sx::k8s::current_namespace)}"
  local -r all_namespaces="${3:-false}"
  local -r selector="${4:-}"
  local -r interval="${5:-2}"
  local -r output="${6:-default}"
  local -r show_labels="${7:-false}"

  local flags=''
  if ${all_namespaces}; then
    flags+=' --all-namespaces'
  elif [ -n "${namespace}" ]; then
    flags+=" --namespace ${namespace}"
  fi

  if [ -n "${selector}" ]; then
    flags+=" --selector ${selector}"
  fi

  if ${show_labels}; then
    flags+=' --show-labels'
  fi

  if [ "${output}" != 'default' ]; then
    flags+=" --output ${output}"
  fi

  # shellcheck disable=SC2086  # intentional word splitting on flags
  if sx::os::is_command_available 'viddy'; then
    exec viddy -n "${interval}" -- ${SX_K8SCTL} get ${resources} ${flags}
  elif sx::os::is_command_available 'hwatch'; then
    exec hwatch -c -n "${interval}" -- ${SX_K8SCTL} get ${resources} ${flags}
  elif sx::os::is_command_available 'watch'; then
    exec watch -c -n "${interval}" -- ${SX_K8SCTL} get ${resources} ${flags}
  else
    sx::log::fatal 'No watch tool found. Install viddy (recommended), hwatch, or watch.'
  fi
}
