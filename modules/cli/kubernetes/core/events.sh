#!/usr/bin/env bash

function sx::k8s::events() {
  sx::k8s::check_requirements

  local -r query="${1:-}"
  local -r namespace="${2:-}"
  local -r all_namespaces="${3:-false}"
  local -r list="${4:-false}"
  local -r warnings="${5:-false}"
  local -r watch="${6:-false}"
  local -r context="${7:-$(sx::k8s::current_context)}"
  local -r selector="${8:-}"

  sx::k8s::validate_context "${context}"
  sx::k8s::ensure_api_access "${context}"

  if ${list}; then
    sx::k8s_command::events "${namespace}" "${all_namespaces}" '' '' "${warnings}" "${watch}" "${context}"
  else
    local -r options="$(
      sx::k8s::resources "${query}" "${namespace}" "${all_namespaces}" true "${context}" "${selector}"
    )"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No resources found'
    fi

    local -r selected="$(sx::select_one 'Please, choose the resource' 1 <<<"${options}")"

    if [ -n "${selected}" ]; then
      local -r ns="$(echo "${selected}" | awk '{ print $1 }')"
      local -r kind="$(echo "${selected}" | awk '{ print $2 }')"
      local -r name="$(echo "${selected}" | awk '{ print $3 }')"

      sx::k8s_command::events "${ns}" 'false' "${kind}" "${name}" "${warnings}" "${watch}" "${context}"
    fi
  fi
}

function sx::k8s_command::events() {
  local -r ns="${1:-}"
  local -r all_namespaces="${2:-false}"
  local -r kind="${3:-}"
  local -r name="${4:-}"
  local -r warnings="${5:-false}"
  local -r watch="${6:-false}"
  local -r context="${7:-}"

  local flags
  readarray -t flags < <(sx::k8s::scope_flags "${ns}" "${all_namespaces}" '' "${context}")

  local field_selector=''
  if [ -n "${kind}" ] && [ -n "${name}" ]; then
    field_selector="involvedObject.kind=${kind},involvedObject.name=${name}"
  fi

  if ${warnings}; then
    if [ -n "${field_selector}" ]; then
      field_selector+=',type=Warning'
    else
      field_selector='type=Warning'
    fi
  fi

  if [ -n "${field_selector}" ]; then
    flags+=(--field-selector "${field_selector}")
  fi

  if ${watch}; then
    flags+=(--watch)
  else
    flags+=(--sort-by=.lastTimestamp)
  fi

  if [ -n "${kind}" ] && [ -n "${name}" ]; then
    sx::log::info "Showing events for ${kind} \"${ns}/${name}\"\n"
  fi

  sx::k8s::cli get events "${flags[@]}"
}
