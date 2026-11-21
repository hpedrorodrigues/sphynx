#!/usr/bin/env bash

export SX_KUBERNETES_TAIL_RESOURCES="${SX_KUBERNETES_TAIL_RESOURCES:-deploy,ds,sts,cj,jobs,po}"

function sx::k8s::tail() {
  sx::k8s::check_requirements

  local -r query="${1:-}"
  local -r namespace="${2:-}"
  local -r all_namespaces="${3:-false}"
  local -r extra_flags="${4:-}"
  local -r context="${5:-}"
  local -r selector="${6:-}"

  sx::k8s::validate_context "${context}"
  sx::k8s::ensure_api_access "${context}"

  if sx::os::is_command_available 'stern'; then
    local -r tool='stern'
  elif sx::os::is_command_available 'kubetail'; then
    local -r tool='kubetail'
  else
    sx::log::fatal 'This command requires "stern" or "kubetail" to be installed'
  fi

  local -r options="$(
    sx::k8s::shared::resources "${SX_KUBERNETES_TAIL_RESOURCES}" "${query}" "${namespace}" "${all_namespaces}" true "${context}" "${selector}"
  )"

  if [ -z "${options}" ]; then
    sx::log::fatal 'No workloads found'
  fi

  local -r selected="$(sx::select_one 'Please, choose the workload' 1 <<<"${options}")"

  if [ -n "${selected}" ]; then
    local -r ns="$(echo "${selected}" | awk '{ print $1 }')"
    local -r kind="$(echo "${selected}" | awk '{ print $2 }')"
    local -r name="$(echo "${selected}" | awk '{ print $3 }')"

    sx::k8s_command::tail "${ns}" "${kind}" "${name}" "${tool}" "${extra_flags}" "${context}"
  fi
}

function sx::k8s_command::tail() {
  local -r ns="${1}"
  local -r kind="${2}"
  local -r name="${3}"
  local -r tool="${4}"
  local -r extra_flags="${5:-}"
  local -r context="${6:-}"

  local -r resource="$(echo "${kind}" | sx::string::lowercase)"

  local context_flags=''
  if [ -n "${context}" ]; then
    if [ "${tool}" = 'kubetail' ]; then
      context_flags="--kube-context ${context}"
    else
      context_flags="--context ${context}"
    fi
  fi

  sx::log::info "Tailing logs from ${kind} \"${ns}/${name}\"\n"

  if [ "${tool}" = 'kubetail' ]; then
    # shellcheck disable=SC2086  # quote this to prevent word splitting
    kubetail logs "${ns}:${resource}s/${name}" --follow ${context_flags} ${extra_flags}
  elif [ "${kind}" = 'CronJob' ]; then
    # stern does not support cronjob resource queries, so match the
    # <cronjob>-<jobid>-<hash> pod names instead
    # shellcheck disable=SC2086  # quote this to prevent word splitting
    stern "^${name}-" --namespace "${ns}" ${context_flags} ${extra_flags}
  else
    # shellcheck disable=SC2086  # quote this to prevent word splitting
    stern "${resource}/${name}" --namespace "${ns}" ${context_flags} ${extra_flags}
  fi
}
