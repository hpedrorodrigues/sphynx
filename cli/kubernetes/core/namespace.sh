#!/usr/bin/env bash

function sx::k8s::namespace() {
  sx::k8s::check_requirements

  local -r query="${1:-}"
  local -r list_namespaces="${2:-false}"

  if ${list_namespaces}; then
    local -r current_namespace="$(sx::k8s::current_namespace)"

    while IFS='' read -r namespace; do
      if echo "${namespace}" | grep -q -E "^${current_namespace} " 2>/dev/null; then
        sx::color::current_item::echo "${namespace}"
      else
        echo "${namespace}"
      fi
    done < <(sx::k8s::cli get namespaces)
  elif sx::os::is_command_available 'fzf'; then
    local -r options="$(sx::k8s::namespaces "${query}")"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No resources found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf ${SX_FZF_ARGS})"

    [ -n "${selected}" ] && sx::k8s::change_namespace "${selected}"
  else
    export PS3=$'\n''Please, choose the resource: '$'\n'

    local options
    readarray -t options < <(sx::k8s::namespaces "${query}")

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No resources found'
    fi

    select selected in "${options[@]}"; do
      sx::k8s::change_namespace "${selected}"
      break
    done
  fi
}

function sx::k8s::namespaces() {
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

function sx::k8s::change_namespace() {
  local -r ns_name="${1:-}"

  sx::k8s::cli config set-context --current --namespace "${ns_name}"
}
