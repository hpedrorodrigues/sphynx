#!/usr/bin/env bash

export SX_KUBERNETES_DEFAULT_RESOURCES='po,deploy,ds,sts,rs,replicationcontrollers,hpa,pdb,endpoints,endpointslices,svc,ing,sa,cm,secrets,jobs,cj,quota,leases,nodes'
export SX_KUBERNETES_RESOURCES="${SX_KUBERNETES_RESOURCES:-${SX_KUBERNETES_DEFAULT_RESOURCES}}"

export SX_KUBERNETES_EDITABLE_RESOURCES="$(echo "${SX_KUBERNETES_RESOURCES}" | sed -E 's/,(nodes|leases|endpoints|endpointslices)//g')"

export SX_K8SCTL="${SX_K8SCTL:-kubectl}"
export SX_K8S_REQUEST_TIMEOUT="${SX_K8S_REQUEST_TIMEOUT:-5s}"
export SX_K8S_CONNECTIVITY_CHECK="${SX_K8S_CONNECTIVITY_CHECK:-false}"

function sx::k8s::check_requirements() {
  sx::require_supported_os
  sx::require 'kubectl'
}

function sx::k8s::can_access_api() {
  # https://kubernetes.io/docs/reference/using-api/health-checks/
  sx::k8s::cli get \
    --raw='/readyz' \
    --request-timeout "${SX_K8S_REQUEST_TIMEOUT}" &>/dev/null
}

function sx::k8s::ensure_api_access() {
  if ${SX_K8S_CONNECTIVITY_CHECK} && ! sx::k8s::can_access_api; then
    sx::log::fatal 'Cannot access API Server!'
  fi
}

function sx::k8s::clear_template() {
  echo -n "${*}" | tr '\n' ' ' | sed 's/}} *{{/}}{{/g' | sed 's/^ *//g'
}

function sx::k8s::age() {
  local -r created_at="${1}"
  local -r now="${2}"

  if [ -z "${created_at}" ]; then
    echo 'Unknown'
    return
  fi

  if sx::os::is_macos; then
    local -r created_at_seconds="$(TZ=UTC date -jf '%Y-%m-%dT%H:%M:%SZ' "${created_at}" '+%s' 2>/dev/null)"
  else
    local -r created_at_seconds="$(date -d "${created_at}" '+%s' 2>/dev/null)"
  fi

  if [ -z "${created_at_seconds}" ]; then
    echo 'Unknown'
    return
  fi

  local -r diff="$((now - created_at_seconds))"
  if [ "${diff}" -ge 86400 ]; then
    echo "$((diff / 86400))d"
  elif [ "${diff}" -ge 3600 ]; then
    echo "$((diff / 3600))h"
  elif [ "${diff}" -ge 60 ]; then
    echo "$((diff / 60))m"
  else
    echo "${diff}s"
  fi
}

function sx::k8s::running_pods() {
  local -r query="${1:-}"
  local -r namespace="${2:-}"
  local -r all_namespaces="${3:-false}"
  local -r print_header="${4:-false}"

  if ${all_namespaces}; then
    local -r flags='--all-namespaces'
  elif [ -n "${namespace}" ]; then
    local -r flags="--namespace ${namespace}"
  else
    local -r flags=''
  fi

  if [ -n "${query}" ]; then
    local -r selector="${query}"
  else
    local -r selector='.*'
  fi

  # shellcheck disable=SC2016  # Expressions don't expand in single quotes, use double quotes for that
  local -r template='
  {{range .items}}
    {{$namespace := .metadata.namespace}}
    {{$name := .metadata.name}}
    {{$created_at := .metadata.creationTimestamp}}
    {{range .status.containerStatuses}}
      {{if .state.running}}
        {{$namespace}}{{","}}{{$name}}{{","}}{{.name}}{{","}}{{.restartCount}}{{","}}{{$created_at}}{{"\n"}}
      {{end}}
    {{end}}
    {{range .status.initContainerStatuses}}
      {{if .state.running}}
        {{$namespace}}{{","}}{{$name}}{{","}}{{.name}}{{","}}{{.restartCount}}{{","}}{{$created_at}}{{"\n"}}
      {{end}}
    {{end}}
  {{end}}'

  local -r header='NAMESPACE,POD NAME,CONTAINER NAME,STATUS,RESTARTS,AGE'
  local -r now="$(date '+%s')"

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  local -r result="$(
    sx::k8s::cli get pods \
      ${flags} \
      --field-selector='status.phase=Running' \
      --output='go-template' \
      --template="$(sx::k8s::clear_template "${template}")" 2>/dev/null \
      | sort -u \
      | grep -E "${selector}" 2>/dev/null \
      | while IFS=',' read -r pod_namespace pod_name container_name restart_count created_at; do
        local pod_age="$(sx::k8s::age "${created_at}" "${now}")"

        echo "${pod_namespace},${pod_name},${container_name},Running,${restart_count},${pod_age}"
      done
  )"

  if [ -z "${result}" ]; then
    echo
  elif ${print_header}; then
    echo -e "${header}\n${result}" | column -t -s ','
  else
    echo -e "${result}" | column -t -s ','
  fi
}

function sx::k8s::current_context() {
  sx::k8s::cli config current-context 2>/dev/null
}

# NOTE: This function is also used by eg commands
function sx::k8s::current_namespace() {
  local -r namespace="$(
    sx::k8s::cli config view \
      --minify \
      --output jsonpath='{.contexts[0].context.namespace}'
  )"

  if [ -z "${namespace}" ]; then
    echo 'default'
  else
    echo "${namespace}"
  fi
}

function sx::k8s::resources() {
  local -r query="${1:-}"
  local -r namespace="${2:-}"
  local -r all_namespaces="${3:-false}"

  sx::k8s::shared::resources "${SX_KUBERNETES_RESOURCES}" "${query}" "${namespace}" "${all_namespaces}"
}

function sx::k8s::editable_resources() {
  local -r query="${1:-}"
  local -r namespace="${2:-}"
  local -r all_namespaces="${3:-false}"

  sx::k8s::shared::resources "${SX_KUBERNETES_EDITABLE_RESOURCES}" "${query}" "${namespace}" "${all_namespaces}"
}

function sx::k8s::shared::resources() {
  local -r resources="${1:-}"
  local -r query="${2:-}"
  local -r namespace="${3:-}"
  local -r all_namespaces="${4:-false}"

  if ${all_namespaces}; then
    local -r flags='--all-namespaces'
  elif [ -n "${namespace}" ]; then
    local -r flags="--namespace ${namespace}"
  else
    local -r flags=''
  fi

  if [ -n "${query}" ]; then
    local -r selector="$(echo "${query}" | sx::string::lowercase)"
  else
    local -r selector='.*'
  fi

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  sx::k8s::cli get "${resources}" \
    ${flags} \
    --output custom-columns=NAMESPACE:.metadata.namespace,KIND:.kind,NAME:.metadata.name \
    --no-headers \
    | sx::string::lowercase \
    | grep -E "${selector}" 2>/dev/null
}

function sx::k8s::nodes() {
  local -r query="${1:-}"
  local -r print_header="${2:-false}"

  if [ -n "${query}" ]; then
    local -r selector="${query}"
  else
    local -r selector='.*'
  fi

  local -r header='NAME,STATUS,AGE'

  local -r result="$(
    sx::k8s::cli get nodes \
      --no-headers \
      | sort -u \
      | grep -E "${selector}" 2>/dev/null \
      | while read -r node_line; do
        local node_name="$(echo "${node_line}" | awk '{ print $1 }')"
        local node_status="$(echo "${node_line}" | awk '{ print $2 }')"
        local node_age="$(echo "${node_line}" | awk '{ print $4 }')"

        echo "${node_name},${node_status},${node_age}"
      done
  )"

  if [ -z "${result}" ]; then
    echo
  elif ${print_header}; then
    echo -e "${header}\n${result}" | column -t -s ','
  else
    echo -e "${result}" | column -t -s ','
  fi
}

function sx::k8s::cli() {
  # shellcheck disable=SC2086  # quote this to prevent word splitting
  ${SX_K8SCTL} "${@}"
}

function sx::k8s::copy_from_pod() {
  local -r ns="${1}"
  local -r name="${2}"
  local -r container="${3}"
  local -r remote_file="${4}"
  local -r local_file="${5}"

  if ! sx::k8s::cli cp \
    --container "${container}" \
    "${ns}/${name}:${remote_file}" \
    "${local_file}" \
    --retries 5; then

    sx::log::fatal "Failed to copy file from pod \"${name}/${container}:${remote_file}\"."
  fi
}
