#!/usr/bin/env bash

function sx::flux::resume() {
  sx::flux::check_requirements

  local -r query="${1:-}"
  local -r namespace="${2:-}"
  local -r all_namespaces="${3:-false}"
  local -r kind="${4:-}"
  local -r name="${5:-}"
  local -r context="${6:-$(sx::k8s::current_context)}"

  sx::k8s::validate_context "${context}"
  sx::k8s::ensure_api_access "${context}"

  if [ -n "${kind}" ] && [ -n "${name}" ]; then
    local -r resolved_kind="$(echo "${kind}" | sx::string::lowercase)"

    sx::flux_command::resume "${namespace}" "${resolved_kind}" "${name}" "${context}"
  else
    local -r options="$(
      sx::flux::resources "${query}" "${namespace}" "${all_namespaces}" "${context}"
    )"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No resources found'
    fi

    local -r selected="$(sx::select_one 'Please, choose the resource' <<<"${options}")"

    if [ -n "${selected}" ]; then
      local -r selected_ns="$(echo "${selected}" | awk '{ print $1 }')"
      local -r selected_kind="$(echo "${selected}" | awk '{ print $2 }')"
      local -r selected_name="$(echo "${selected}" | awk '{ print $3 }')"

      sx::flux_command::resume "${selected_ns}" "${selected_kind}" "${selected_name}" "${context}"
    fi
  fi
}

function sx::flux_command::resume() {
  local -r ns="${1}"
  local -r kind="${2}"
  local -r name="${3}"
  local -r context="${4:-}"

  local -r flux_type="$(sx::flux::kind_to_type "${kind}")"

  local ns_flag=''
  if [ -n "${ns}" ]; then
    ns_flag="--namespace ${ns}"
  fi

  local -r context_flags="$(sx::k8s::context_flags "${context}")"

  sx::log::info "Resuming ${kind} \"${ns:-default}/${name}\"\n"

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  sx::flux::cli resume ${flux_type} "${name}" ${ns_flag} ${context_flags}
}
