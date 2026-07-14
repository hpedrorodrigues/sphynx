#!/usr/bin/env bash

readonly traceable_resources='service,deployment'

function sx::k8s::trace() {
  sx::k8s::check_requirements
  sx::require 'kubespy'

  local -r query="${1:-}"
  local -r namespace="${2:-}"
  local -r all_namespaces="${3:-false}"
  local -r context="${4:-}"
  local -r selector="${5:-}"

  sx::k8s::validate_context "${context}"
  sx::k8s::ensure_api_access "${context}"

  if sx::os::is_command_available 'fzf'; then
    local -r options="$(
      sx::k8s::shared::resources "${traceable_resources}" "${query}" "${namespace}" "${all_namespaces}" true "${context}" "${selector}"
    )"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No resources found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf --header-lines 1 ${SX_FZF_ARGS})"

    if [ -n "${selected}" ]; then
      local -r ns="$(echo "${selected}" | awk '{ print $1 }')"
      local -r kind="$(echo "${selected}" | awk '{ print $2 }')"
      local -r name="$(echo "${selected}" | awk '{ print $3 }')"

      sx::k8s_command::trace "${ns}" "${kind}" "${name}" "${context}"
    fi
  else
    export PS3=$'\n''Please, choose the resource: '$'\n'

    local options
    readarray -t options < <(
      sx::k8s::shared::resources "${traceable_resources}" "${query}" "${namespace}" "${all_namespaces}" false "${context}" "${selector}"
    )

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No resources found'
    fi

    select selected in "${options[@]}"; do
      if [ -z "${selected}" ]; then
        sx::log::err "Invalid option \"${REPLY}\". Please, type the number of the desired option."
        continue
      fi

      local -r ns="$(echo "${selected}" | awk '{ print $1 }')"
      local -r kind="$(echo "${selected}" | awk '{ print $2 }')"
      local -r name="$(echo "${selected}" | awk '{ print $3 }')"

      sx::k8s_command::trace "${ns}" "${kind}" "${name}" "${context}"
      break
    done
  fi
}

function sx::k8s_command::trace() {
  local -r ns="${1:-}"
  local -r kind="${2:-}"
  local -r name="${3:-}"
  local -r context="${4:-}"

  sx::log::info "Tracing ${kind} \"${ns}/${name}\"\n"

  if [ -z "${context}" ]; then
    kubespy trace "${kind}" "${ns}/${name}"
    return
  fi

  # kubespy exposes no --context flag, so point it at a temporary self-contained
  # kubeconfig whose current-context is the requested one (kubespy honors KUBECONFIG).
  local -r kubeconfig="$(mktemp -t sphynx_trace_kubeconfig || echo "/tmp/sphynx_trace_kubeconfig.$$")"
  # shellcheck disable=SC2064  # expand kubeconfig now so the trap cleans up the right file
  trap "rm -f '${kubeconfig}'" RETURN

  sx::k8s::cli config view --minify --flatten --context "${context}" >"${kubeconfig}" 2>/dev/null

  KUBECONFIG="${kubeconfig}" kubespy trace "${kind}" "${ns}/${name}"
}
