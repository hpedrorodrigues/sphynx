#!/usr/bin/env bash

export SX_NS_STACK_FILE="${SX_NS_STACK_FILE:-${HOME}/.kube/sphynx_namespaces}"

function sx::k8s::namespace() {
  sx::k8s::check_requirements

  local -r query="${1:-}"
  local -r exact_namespace="${2:-}"
  local -r list_namespaces="${3:-false}"

  if [ -n "${exact_namespace}" ]; then
    sx::k8s_command::namespace::change "${exact_namespace}"
  elif [ "${query}" = '-' ]; then
    ! [ -f "${SX_NS_STACK_FILE}" ] && return

    local -r last_namespace="$(tail -n1 "${SX_NS_STACK_FILE}")"

    tail -n1 "${SX_NS_STACK_FILE}" \
      | wc -c \
      | xargs -I % truncate "${SX_NS_STACK_FILE}" -s -%

    sx::k8s_command::namespace::change "${last_namespace}"
  elif ${list_namespaces}; then
    sx::k8s::ensure_api_access

    local -r current_namespace="$(sx::k8s::current_namespace)"

    while IFS='' read -r namespace; do
      if echo "${namespace}" | grep -q -E "^${current_namespace} " 2>/dev/null; then
        sx::color::current_item::echo "${namespace}"
      else
        echo "${namespace}"
      fi
    done < <(sx::k8s::cli get namespaces)
  elif sx::os::is_command_available 'fzf'; then
    sx::k8s::ensure_api_access

    local -r options="$(sx::k8s_command::namespace::names "${query}")"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No resources found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf ${SX_FZF_ARGS})"

    [ -n "${selected}" ] && sx::k8s_command::namespace::change "${selected}"
  else
    sx::k8s::ensure_api_access

    export PS3=$'\n''Please, choose the resource: '$'\n'

    local options
    readarray -t options < <(sx::k8s_command::namespace::names "${query}")

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No resources found'
    fi

    select selected in "${options[@]}"; do
      sx::k8s_command::namespace::change "${selected}"
      break
    done
  fi
}

function sx::k8s_command::namespace::names() {
  local -r query="${1:-}"

  if [ -n "${query}" ]; then
    local -r selector="$(echo "${query}" | sx::string::lowercase)"
  else
    local -r selector='.*'
  fi

  local -r namespaces="$(
    sx::k8s::cli get namespaces \
      --output custom-columns=NAME:.metadata.name \
      --no-headers \
      | sx::string::lowercase \
      | grep -E "${selector}"
  )"
  local -r current_namespace="$(sx::k8s::current_namespace)"

  # shellcheck disable=SC2068  # Double quote array expansions
  for namespace in ${namespaces[@]}; do
    if [ "${current_namespace}" = "${namespace}" ]; then
      sx::color::current_item::echo "${namespace}"
    else
      echo "${namespace}"
    fi
  done
}

function sx::k8s_command::namespace::change() {
  local -r new_namespace="${1:-}"

  local -r current_namespace="$(sx::k8s::current_namespace)"
  if [ "${current_namespace}" != "${new_namespace}" ]; then
    sx::k8s::current_namespace >>"${SX_NS_STACK_FILE}"
  fi

  sx::k8s::cli config set-context --current --namespace "${new_namespace}"
}
