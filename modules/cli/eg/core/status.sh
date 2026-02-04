#!/usr/bin/env bash

function sx::eg::status() {
  sx::eg::check_requirements

  local -r kind="${1:-}"
  local -r namespace="${2:-}"
  local -r all_namespaces="${3:-false}"
  local -r verbose="${4:-false}"

  if [ -n "${kind}" ]; then
    sx::eg_command::status "${kind}" "${namespace}" "${all_namespaces}" "${verbose}"
  elif sx::os::is_command_available 'fzf'; then
    local -r options="$(sx::eg::resource_kinds true)"

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf --header-lines 1 ${SX_FZF_ARGS})"

    if [ -n "${selected}" ]; then
      sx::eg_command::status "${selected}" "${namespace}" "${all_namespaces}" "${verbose}"
    fi
  else
    export PS3=$'\n''Please, choose the resource kind: '$'\n'

    local options
    readarray -t options < <(sx::eg::resource_kinds)

    select selected in "${options[@]}"; do
      sx::eg_command::status "${selected}" "${namespace}" "${all_namespaces}" "${verbose}"
      break
    done
  fi
}

function sx::eg_command::status() {
  local -r kind="${1}"
  local -r namespace="${2:-}"
  local -r all_namespaces="${3:-false}"
  local -r verbose="${4:-false}"

  local flags=''
  if ${all_namespaces}; then
    flags+=' --all-namespaces'
  elif [ -n "${namespace}" ]; then
    flags+=" --namespace ${namespace}"
  fi

  if ${verbose}; then
    flags+=' --verbose'
  fi

  sx::log::info "Fetching status for ${kind} resources\n"

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  sx::eg::cli experimental status "${kind}" ${flags}
}
