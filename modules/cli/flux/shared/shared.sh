#!/usr/bin/env bash

export SX_FLUX_DEFAULT_RESOURCES='GitRepository,HelmRepository,OCIRepository,Bucket,HelmChart,Kustomization,HelmRelease,Alert,Provider,Receiver,ImageRepository,ImagePolicy,ImageUpdateAutomation'
export SX_FLUX_RESOURCES="${SX_FLUX_RESOURCES:-${SX_FLUX_DEFAULT_RESOURCES}}"

export SX_FLUXCTL="${SX_FLUXCTL:-flux}"

function sx::flux::check_requirements() {
  sx::require_supported_os
  sx::require 'flux'
  sx::require 'kubectl'
}

function sx::flux::cli() {
  # shellcheck disable=SC2086  # quote this to prevent word splitting
  ${SX_FLUXCTL} "${@}"
}

function sx::flux::resources() {
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
    local -r selector="$(echo "${query}" | sx::string::lowercase)"
  else
    local -r selector='.*'
  fi

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  kubectl get "${SX_FLUX_RESOURCES}" \
    ${flags} \
    --output custom-columns=NAMESPACE:.metadata.namespace,KIND:.kind,NAME:.metadata.name \
    --no-headers 2>/dev/null \
    | sx::string::lowercase \
    | grep -E "${selector}" 2>/dev/null
}

function sx::flux::suspended_resources() {
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
    local -r selector="$(echo "${query}" | sx::string::lowercase)"
  else
    local -r selector='.*'
  fi

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  kubectl get "${SX_FLUX_RESOURCES}" \
    ${flags} \
    --output custom-columns=NAMESPACE:.metadata.namespace,KIND:.kind,NAME:.metadata.name,SUSPENDED:.spec.suspend \
    --no-headers 2>/dev/null \
    | sx::string::lowercase \
    | grep -E '\btrue$' \
    | awk '{ print $1, $2, $3 }' \
    | grep -E "${selector}" 2>/dev/null
}

function sx::flux::kind_to_type() {
  local -r kind="${1}"

  case "${kind}" in
    gitrepository | gitrepo) echo 'source git' ;;
    helmrepository | helmrepo) echo 'source helm' ;;
    ocirepository | ocirepo) echo 'source oci' ;;
    bucket) echo 'source bucket' ;;
    helmchart) echo 'source chart' ;;
    kustomization | ks) echo 'kustomization' ;;
    helmrelease | hr) echo 'helmrelease' ;;
    alert) echo 'alert' ;;
    provider) echo 'alert-provider' ;;
    receiver) echo 'receiver' ;;
    imagerepository | imagerepo) echo 'image repository' ;;
    imagepolicy) echo 'image policy' ;;
    imageupdateautomation | imageauto) echo 'image update' ;;
    *) sx::log::fatal "Unknown Flux kind: ${kind}" ;;
  esac
}
