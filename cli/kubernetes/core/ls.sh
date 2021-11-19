#!/usr/bin/env bash

function sx::k8s::list::resources() {
  sx::k8s::check_requirements
  sx::k8s::ensure_api_access

  local -r namespace="${1:-$(sx::k8s::current_namespace)}"
  local -r output="${2:-}"
  local -r all_namespaces="${3:-false}"
  local -r show_labels="${4:-false}"

  local flags=''
  if ${all_namespaces}; then
    flags+=' --all-namespaces'
  elif [ -n "${namespace}" ]; then
    flags+=" --namespace ${namespace}"
  fi

  if ${show_labels}; then
    flags+=' --show-labels'
  fi

  if [ "${output}" != 'default' ]; then
    flags+=" --output ${output}"
  fi

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  sx::k8s::cli get "${SX_KUBERNETES_RESOURCES}" ${flags}
}
