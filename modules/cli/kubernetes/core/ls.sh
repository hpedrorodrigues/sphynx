#!/usr/bin/env bash

function sx::k8s::list::resources() {
  sx::k8s::check_requirements

  local -r context="${5:-$(sx::k8s::current_context)}"
  local -r selector="${6:-}"

  sx::k8s::validate_context "${context}"
  sx::k8s::ensure_api_access "${context}"

  local -r namespace="${1:-$(sx::k8s::current_namespace "${context}")}"
  local -r output="${2:-}"
  local -r all_namespaces="${3:-false}"
  local -r show_labels="${4:-false}"

  local flags
  readarray -t flags < <(sx::k8s::scope_flags "${namespace}" "${all_namespaces}" "${selector}" "${context}")

  if ${show_labels}; then
    flags+=(--show-labels)
  fi

  if [ "${output}" != 'default' ]; then
    flags+=(--output "${output}")
  fi

  sx::k8s::cli get "${SX_KUBERNETES_RESOURCES}" "${flags[@]}"
}
