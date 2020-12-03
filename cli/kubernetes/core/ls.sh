#!/usr/bin/env bash

function sx::k8s::list::resources() {
  sx::k8s::check_requirements

  local -r namespace="${1:-$(sx::k8s::current_namespace)}"
  local -r all_namespaces="${2:-false}"
  local -r show_labels="${3:-false}"

  local flags=''
  if ${all_namespaces}; then
    flags+=' --all-namespaces'
  elif [ -n "${namespace}" ]; then
    flags+=" --namespace ${namespace}"
  fi

  if ${show_labels}; then
    flags+=' --show-labels'
  fi

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  sx::k8s::cli get "${SX_KUBERNETES_RESOURCES}" ${flags}
}
