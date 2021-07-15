#!/usr/bin/env bash

export SX_KUBERNETES_DEFAULT_RESOURCES='po,deploy,ds,sts,rs,replicationcontrollers,hpa,pdb,endpoints,endpointslices,svc,ing,sa,cm,secrets,jobs,cj,quota,leases,nodes'
export SX_KUBERNETES_RESOURCES="${SX_KUBERNETES_RESOURCES:-${SX_KUBERNETES_DEFAULT_RESOURCES}}"

export SX_KUBERNETES_EDITABLE_RESOURCES="$(echo "${SX_KUBERNETES_RESOURCES}" | sed -E 's/,(nodes|leases|endpoints|endpointslices)//g')"

export SX_K8SCTL="${SX_K8SCTL:-kubectl}"
export SX_K8S_REQUEST_TIMEOUT="${SX_K8S_REQUEST_TIMEOUT:-0}"

function sx::k8s::check_requirements() {
  sx::require_supported_os
  sx::require 'kubectl'
}

function sx::k8s::clear_template() {
  echo -n "${*}" | tr '\n' ' ' | sed 's/}} *{{/}}{{/g' | sed 's/^ *//g'
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
    {{range .spec.containers}}
      {{$namespace}}{{","}}{{$name}}{{","}}{{.name}}{{"\n"}}
    {{end}}
  {{end}}'

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  local -r simple_pods_output="$(
    sx::k8s::cli get pods \
      ${flags} 2>/dev/null \
      | grep -E "${selector}" 2>/dev/null
  )"

  local -r header='NAMESPACE,POD NAME,CONTAINER NAME,STATUS,RESTARTS,AGE'

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  local -r result="$(
    sx::k8s::cli get pods \
      ${flags} \
      --output go-template \
      --template="$(sx::k8s::clear_template "${template}")" 2>/dev/null \
      | sort -u \
      | column -t -s ',' \
      | grep -E "${selector}" 2>/dev/null \
      | while read -r templated_pod_line; do
        local pod_name="$(echo "${templated_pod_line}" | awk '{ print $2 }')"

        local simple_pod_line="$(echo -e "${simple_pods_output}" | grep "${pod_name}")"
        local pod_status="$(echo -e "${simple_pod_line}" | awk '{ print $3 }')"

        if echo "${pod_status}" | grep -q -v 'Running'; then
          continue
        fi

        local pod_namespace="$(echo "${templated_pod_line}" | awk '{ print $1 }')"
        local container_name="$(echo "${templated_pod_line}" | awk '{ print $3 }')"

        local pod_restarts_count="$(echo -e "${simple_pod_line}" | awk '{ print $4 }')"
        local pod_age="$(echo -e "${simple_pod_line}" | awk '{ print $5 }')"

        echo "${pod_namespace},${pod_name},${container_name},${pod_status},${pod_restarts_count},${pod_age}"
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
  sx::k8s::cli config current-context
}

function sx::k8s::current_namespace() {
  local -r current_context="$(sx::k8s::current_context)"
  local -r namespace="$(
    sx::k8s::cli \
      config view \
      --output jsonpath="{.contexts[?(@.name==\"${current_context}\")].context.namespace}"
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
  command ${SX_K8SCTL} --request-timeout "${SX_K8S_REQUEST_TIMEOUT}" "${@}"
}
