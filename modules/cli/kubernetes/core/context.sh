#!/usr/bin/env bash

export SX_K8S_CTX_FILE="${SX_K8S_CTX_FILE:-${HOME}/.kube/sphynx_contexts}"

function sx::k8s::context() {
  sx::k8s::check_requirements

  local -r query="${1:-}"
  local -r exact_context="${2:-}"
  local -r list_contexts="${3:-false}"

  if [ -n "${exact_context}" ]; then
    sx::k8s_command::context::change "${exact_context}"
  elif [ "${query}" = '-' ]; then
    local -r last_context="$(sx::file::read "${SX_K8S_CTX_FILE}")"

    # return when there is no previous context
    [ -z "${last_context}" ] && return

    sx::k8s_command::context::change "${last_context}"
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
    local -r options="$(sx::k8s_command::context::names "${query}")"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No resources found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf ${SX_FZF_ARGS})"

    [ -n "${selected}" ] && sx::k8s_command::context::change "${selected}"
  else
    export PS3=$'\n''Please, choose the resource: '$'\n'

    local options
    readarray -t options < <(sx::k8s_command::context::names "${query}")

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No resources found'
    fi

    select selected in "${options[@]}"; do
      sx::k8s_command::context::change "${selected}"
      break
    done
  fi
}

function sx::k8s_command::context::names() {
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

function sx::k8s_command::context::change() {
  local -r new_context="${1:-}"

  local -r current_context="$(sx::k8s::current_context)"
  [ "${current_context}" != "${new_context}" ] \
    && [ -n "${current_context}" ] \
    && sx::file::write_replacing "${SX_K8S_CTX_FILE}" "${current_context}"

  sx::k8s::cli config use-context "${new_context}"
}
