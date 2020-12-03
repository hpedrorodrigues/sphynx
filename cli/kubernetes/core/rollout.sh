#!/usr/bin/env bash

function sx::k8s::rollout() {
  sx::k8s::check_requirements

  local -r action="${1}"
  local -r query="${2:-}"
  local -r namespace="${3:-}"
  local -r all_namespaces="${4:-false}"

  if sx::os::is_command_available 'fzf'; then
    local -r options="$(
      sx::k8s::rollout::resources "${query}" "${namespace}" "${all_namespaces}"
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

      sx::k8s_command::rollout "${action}" "${ns}" "${kind}" "${name}"
    fi
  else
    export PS3=$'\n''Please, choose the resource: '$'\n'

    local options
    mapfile -t options < <(
      sx::k8s::rollout::resources "${query}" "${namespace}" "${all_namespaces}"
    )

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No resources found'
    fi

    select selected in "${options[@]}"; do
      local -r ns="$(echo "${selected}" | awk '{ print $1 }')"
      local -r kind="$(echo "${selected}" | awk '{ print $2 }')"
      local -r name="$(echo "${selected}" | awk '{ print $3 }')"

      sx::k8s_command::rollout "${action}" "${ns}" "${kind}" "${name}"
      break
    done
  fi
}

function sx::k8s::rollout::resources() {
  local -r query="${1:-}"
  local -r namespace="${2:-}"
  local -r all_namespaces="${3:-false}"
  local -r resources='deployments,daemonsets,statefulsets'

  sx::k8s::shared::resources \
    "${resources}" \
    "${query}" \
    "${namespace}" \
    "${all_namespaces}"
}

function sx::k8s_command::rollout() {
  local -r action="${1}"
  local -r ns="${2}"
  local -r kind="${3}"
  local -r name="${4}"

  sx::k8s::cli rollout "${action}" --namespace "${ns}" "${kind}" "${name}"
}

function sx::k8s::rollout::restart() {
  local -r query="${1:-}"
  local -r namespace="${2:-}"
  local -r all_namespaces="${3:-false}"

  sx::k8s::rollout 'restart' \
    "${query:-}" \
    "${namespace:-}" \
    "${all_namespaces:-false}"
}

function sx::k8s::rollout::status() {
  local -r query="${1:-}"
  local -r namespace="${2:-}"
  local -r all_namespaces="${3:-false}"

  sx::k8s::rollout 'status' \
    "${query:-}" \
    "${namespace:-}" \
    "${all_namespaces:-false}"
}

function sx::k8s::rollout::history() {
  local -r query="${1:-}"
  local -r namespace="${2:-}"
  local -r all_namespaces="${3:-false}"

  sx::k8s::rollout 'history' \
    "${query:-}" \
    "${namespace:-}" \
    "${all_namespaces:-false}"
}
