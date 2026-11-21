#!/usr/bin/env bash

function sx::k8s::rollout() {
  sx::k8s::check_requirements

  local -r action="${1}"
  local -r query="${2:-}"
  local -r namespace="${3:-}"
  local -r all_namespaces="${4:-false}"
  local -r context="${5:-}"
  local -r selector="${6:-}"

  sx::k8s::validate_context "${context}"
  sx::k8s::ensure_api_access "${context}"

  local -r options="$(
    sx::k8s::rollout::resources "${query}" "${namespace}" "${all_namespaces}" true "${context}" "${selector}"
  )"

  if [ -z "${options}" ]; then
    sx::log::fatal 'No resources found'
  fi

  local -r selected="$(sx::select_one 'Please, choose the resource' 1 <<<"${options}")"

  if [ -n "${selected}" ]; then
    local -r ns="$(echo "${selected}" | awk '{ print $1 }')"
    local -r kind="$(echo "${selected}" | awk '{ print $2 }')"
    local -r name="$(echo "${selected}" | awk '{ print $3 }')"

    sx::k8s_command::rollout "${action}" "${ns}" "${kind}" "${name}" "${context}"
  fi
}

function sx::k8s::rollout::resources() {
  local -r query="${1:-}"
  local -r namespace="${2:-}"
  local -r all_namespaces="${3:-false}"
  local -r print_header="${4:-false}"
  local -r context="${5:-}"
  local -r selector="${6:-}"
  local -r resources='deployments,daemonsets,statefulsets'

  sx::k8s::shared::resources \
    "${resources}" \
    "${query}" \
    "${namespace}" \
    "${all_namespaces}" \
    "${print_header}" \
    "${context}" \
    "${selector}"
}

function sx::k8s_command::rollout() {
  local -r action="${1}"
  local -r ns="${2}"
  local -r kind="${3}"
  local -r name="${4}"
  local -r context="${5:-}"

  local -r context_flags="$(sx::k8s::context_flags "${context}")"

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  sx::k8s::cli ${context_flags} rollout "${action}" --namespace "${ns}" "${kind}" "${name}"
}

function sx::k8s::rollout::restart() {
  local -r query="${1:-}"
  local -r namespace="${2:-}"
  local -r all_namespaces="${3:-false}"
  local -r context="${4:-}"
  local -r selector="${5:-}"

  sx::k8s::rollout 'restart' \
    "${query:-}" \
    "${namespace:-}" \
    "${all_namespaces:-false}" \
    "${context:-}" \
    "${selector:-}"
}

function sx::k8s::rollout::status() {
  local -r query="${1:-}"
  local -r namespace="${2:-}"
  local -r all_namespaces="${3:-false}"
  local -r context="${4:-}"
  local -r selector="${5:-}"

  sx::k8s::rollout 'status' \
    "${query:-}" \
    "${namespace:-}" \
    "${all_namespaces:-false}" \
    "${context:-}" \
    "${selector:-}"
}

function sx::k8s::rollout::history() {
  local -r query="${1:-}"
  local -r namespace="${2:-}"
  local -r all_namespaces="${3:-false}"
  local -r context="${4:-}"
  local -r selector="${5:-}"

  sx::k8s::rollout 'history' \
    "${query:-}" \
    "${namespace:-}" \
    "${all_namespaces:-false}" \
    "${context:-}" \
    "${selector:-}"
}
