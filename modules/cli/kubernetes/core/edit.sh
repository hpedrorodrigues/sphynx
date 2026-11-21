#!/usr/bin/env bash

function sx::k8s::edit() {
  sx::k8s::check_requirements

  local -r query="${1:-}"
  local -r namespace="${2:-}"
  local -r all_namespaces="${3:-false}"
  local -r context="${4:-}"
  local -r selector="${5:-}"

  sx::k8s::validate_context "${context}"
  sx::k8s::ensure_api_access "${context}"

  local -r options="$(
    sx::k8s::editable_resources "${query}" "${namespace}" "${all_namespaces}" true "${context}" "${selector}"
  )"

  if [ -z "${options}" ]; then
    sx::log::fatal 'No resources found'
  fi

  local -r selected="$(sx::select_one 'Please, choose the resource' 1 <<<"${options}")"

  if [ -n "${selected}" ]; then
    local -r ns="$(echo "${selected}" | awk '{ print $1 }')"
    local -r kind="$(echo "${selected}" | awk '{ print $2 }')"
    local -r name="$(echo "${selected}" | awk '{ print $3 }')"

    sx::k8s_command::edit "${ns}" "${kind}" "${name}" "${context}"
  fi
}

function sx::k8s_command::edit() {
  local -r ns="${1:-}"
  local -r kind="${2:-}"
  local -r name="${3:-}"
  local -r context="${4:-}"

  local -r context_flags="$(sx::k8s::context_flags "${context}")"

  sx::log::info "Editing ${kind} \"${ns}/${name}\"\n"

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  sx::k8s::cli ${context_flags} --namespace "${ns}" edit "${kind}" "${name}"
}
