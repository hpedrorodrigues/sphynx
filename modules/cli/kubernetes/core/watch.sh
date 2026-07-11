#!/usr/bin/env bash

function sx::k8s::watch::resources() {
  sx::k8s::check_requirements

  local -r resources="${1:-pods}"
  local -r namespace="${2:-}"
  local -r all_namespaces="${3:-false}"
  local -r selector="${4:-}"
  local -r interval="${5:-2}"
  local -r output="${6:-default}"
  local -r show_labels="${7:-false}"
  local -r context="${8:-}"

  sx::k8s::validate_context "${context}"
  sx::k8s::ensure_api_access "${context}"

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

  if [ -n "${context}" ]; then
    flags+=" --context ${context}"
  fi

  # shellcheck disable=SC2086  # intentional word splitting on flags
  sx::os::watcher "${interval}" ${SX_K8SCTL} get ${resources} ${flags}
}
