#!/usr/bin/env bash

function sx::k8s::context() {
  sx::k8s::check_requirements

  local -r query="${1:-}"
  local -r exact_context="${2:-}"
  local -r list_contexts="${3:-false}"

  if [ -n "${exact_context}" ]; then
    sx::k8s::change_context "${exact_context}"
  elif ${list_contexts}; then
    local -r current_context="$(sx::k8s::current_context)"

    while IFS='' read -r context; do
      if echo "${context}" | grep -q " ${current_context} " 2>/dev/null; then
        sx::color::current_item::echo "${context}"
      else
        echo "${context}"
      fi
    done < <(sx::k8s::cli config get-contexts)
  elif sx::os::is_command_available 'fzf'; then
    local -r options="$(sx::k8s::contexts "${query}")"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No resources found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf ${SX_FZF_ARGS})"

    [ -n "${selected}" ] && sx::k8s::change_context "${selected}"
  else
    export PS3=$'\n''Please, choose the resource: '$'\n'

    local options
    readarray -t options < <(sx::k8s::contexts "${query}")

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No resources found'
    fi

    select selected in "${options[@]}"; do
      sx::k8s::change_context "${selected}"
      break
    done
  fi
}

function sx::k8s::contexts() {
  local -r query="${1:-}"

  if [ -n "${query}" ]; then
    local -r selector="$(echo "${query}" | sx::string::lowercase)"
  else
    local -r selector='.*'
  fi

  local -r contexts="$(
    sx::k8s::cli config get-contexts \
      --output name \
      | sx::string::lowercase \
      | grep -E "${selector}"
  )"
  local -r current_context="$(sx::k8s::current_context)"

  # shellcheck disable=SC2068  # Double quote array expansions
  for context in ${contexts[@]}; do
    if [ "${current_context}" = "${context}" ]; then
      sx::color::current_item::echo "${context}"
    else
      echo "${context}"
    fi
  done
}

function sx::k8s::change_context() {
  local -r ctx_name="${1:-}"

  sx::k8s::cli config use-context "${ctx_name}"
}
