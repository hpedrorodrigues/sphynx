#!/usr/bin/env bash

readonly traceable_resources='service,deployment'

function sx::k8s::trace() {
  sx::k8s::check_requirements
  sx::k8s::ensure_api_access
  sx::require 'kubespy'

  local -r query="${1:-}"
  local -r namespace="${2:-}"
  local -r all_namespaces="${3:-false}"

  if sx::os::is_command_available 'fzf'; then
    local -r options="$(
      sx::k8s::shared::resources "${traceable_resources}" "${query}" "${namespace}" "${all_namespaces}"
    )"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No resources found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf ${SX_FZF_ARGS})"

    if [ -n "${selected}" ]; then
      local -r ns="$(echo "${selected}" | awk '{ print $1 }')"
      local -r kind="$(echo "${selected}" | awk '{ print $2 }')"
      local -r name="$(echo "${selected}" | awk '{ print $3 }')"

      sx::k8s_command::trace "${ns}" "${kind}" "${name}"
    fi
  else
    export PS3=$'\n''Please, choose the resource: '$'\n'

    local options
    readarray -t options < <(
      sx::k8s::shared::resources "${traceable_resources}" "${query}" "${namespace}" "${all_namespaces}"
    )

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No resources found'
    fi

    select selected in "${options[@]}"; do
      local -r ns="$(echo "${selected}" | awk '{ print $1 }')"
      local -r kind="$(echo "${selected}" | awk '{ print $2 }')"
      local -r name="$(echo "${selected}" | awk '{ print $3 }')"

      sx::k8s_command::trace "${ns}" "${kind}" "${name}"
      break
    done
  fi
}

function sx::k8s_command::trace() {
  local -r ns="${1:-}"
  local -r kind="${2:-}"
  local -r name="${3:-}"

  sx::log::info "Tracing ${kind} \"${ns}/${name}\"\n"

  kubespy trace "${kind}" "${ns}/${name}"
}
