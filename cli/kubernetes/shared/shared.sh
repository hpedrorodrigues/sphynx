#!/usr/bin/env bash

export SX_KUBERNETES_DEFAULT_RESOURCES='po,deploy,ds,sts,rs,replicationcontrollers,hpa,pdb,endpoints,endpointslices,svc,ing,sa,cm,secrets,jobs,cj,quota,leases,nodes'
export SX_KUBERNETES_RESOURCES="${SX_KUBERNETES_RESOURCES:-${SX_KUBERNETES_DEFAULT_RESOURCES}}"

export SX_KUBERNETES_EDITABLE_RESOURCES="$(echo "${SX_KUBERNETES_RESOURCES}" | sed -E 's/,(nodes|leases|endpoints|endpointslices)//g')"

export SX_K8SCTL="${SX_K8SCTL:-kubectl}"
export SX_K8S_REQUEST_TIMEOUT="${SX_K8S_REQUEST_TIMEOUT:-0}"

function sx::k8s::check_requirements() {
  sx::require 'kubectl'
}

function sx::k8s::clear_template() {
  echo -n "${*}" | tr '\n' ' ' | sed 's/}} *{{/}}{{/g' | sed 's/^ *//g'
}

function sx::k8s::running_pods() {
  local -r query="${1:-}"
  local -r namespace="${2:-}"
  local -r all_namespaces="${3:-false}"

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

  local -r template='
  {{range .items}}
    {{if eq .status.phase "Running"}}
      {{.metadata.namespace}}{{","}}{{.metadata.name}}{{","}}{{.status.phase}}{{"\n"}}
    {{end}}
  {{end}}'

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  sx::k8s::cli get pods \
    ${flags} \
    --output go-template \
    --template="$(sx::k8s::clear_template "${template}")" \
    | sort -u \
    | column -t -s ',' \
    | grep -E "${selector}" 2>/dev/null
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

function sx::k8s::cli() {
  "${SX_K8SCTL}" --request-timeout "${SX_K8S_REQUEST_TIMEOUT}" "${@}"
}
