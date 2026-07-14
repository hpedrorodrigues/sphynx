#!/usr/bin/env bash

function sx::k8s::events() {
  sx::k8s::check_requirements

  local -r query="${1:-}"
  local -r namespace="${2:-}"
  local -r all_namespaces="${3:-false}"
  local -r list="${4:-false}"
  local -r warnings="${5:-false}"
  local -r watch="${6:-false}"
  local -r context="${7:-}"
  local -r selector="${8:-}"

  sx::k8s::validate_context "${context}"
  sx::k8s::ensure_api_access "${context}"

  if ${list}; then
    sx::k8s_command::events "${namespace}" "${all_namespaces}" '' '' "${warnings}" "${watch}" "${context}"
  elif sx::os::is_command_available 'fzf'; then
    local -r options="$(
      sx::k8s::resources "${query}" "${namespace}" "${all_namespaces}" true "${context}" "${selector}"
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

      sx::k8s_command::events "${ns}" 'false' "${kind}" "${name}" "${warnings}" "${watch}" "${context}"
    fi
  else
    export PS3=$'\n''Please, choose the resource: '$'\n'

    local options
    readarray -t options < <(
      sx::k8s::resources "${query}" "${namespace}" "${all_namespaces}" false "${context}" "${selector}"
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

      sx::k8s_command::events "${ns}" 'false' "${kind}" "${name}" "${warnings}" "${watch}" "${context}"
      break
    done
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

  local flags=''
  if ${all_namespaces}; then
    flags+=' --all-namespaces'
  elif [ -n "${ns}" ]; then
    flags+=" --namespace ${ns}"
  fi

  if [ -n "${context}" ]; then
    flags+=" --context ${context}"
  fi

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
    flags+=" --field-selector ${field_selector}"
  fi

  if ${watch}; then
    flags+=' --watch'
  else
    flags+=' --sort-by=.lastTimestamp'
  fi

  if [ -n "${kind}" ] && [ -n "${name}" ]; then
    sx::log::info "Showing events for ${kind} \"${ns}/${name}\"\n"
  fi

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  sx::k8s::cli get events ${flags}
}
