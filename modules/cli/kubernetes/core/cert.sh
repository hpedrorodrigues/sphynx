#!/usr/bin/env bash

function sx::k8s::cert::inspect() {
  sx::k8s::check_requirements
  sx::require 'cmctl' 'cert-manager CLI (cmctl)'

  # shellcheck disable=SC2016  # Expressions don't expand in single quotes, use double quotes for that
  local -r template='
  {{range .items}}
    {{if eq .type "kubernetes.io/tls"}}
      {{.metadata.namespace}}{{","}}{{.metadata.name}}{{","}}{{.metadata.creationTimestamp}}{{"\n"}}
    {{end}}
  {{end}}'

  sx::k8s::cert::pick 'secrets' "${template}" sx::k8s_command::cert::inspect "${@}"
}

function sx::k8s::cert::status() {
  sx::k8s::check_requirements
  sx::require 'cmctl' 'cert-manager CLI (cmctl)'

  # shellcheck disable=SC2016  # Expressions don't expand in single quotes, use double quotes for that
  local -r template='
  {{range .items}}
    {{.metadata.namespace}}{{","}}{{.metadata.name}}{{","}}{{.metadata.creationTimestamp}}{{"\n"}}
  {{end}}'

  sx::k8s::cert::pick 'certificates.cert-manager.io' "${template}" sx::k8s_command::cert::status "${@}"
}

function sx::k8s::cert::renew() {
  sx::k8s::check_requirements
  sx::require 'cmctl' 'cert-manager CLI (cmctl)'

  # shellcheck disable=SC2016  # Expressions don't expand in single quotes, use double quotes for that
  local -r template='
  {{range .items}}
    {{.metadata.namespace}}{{","}}{{.metadata.name}}{{","}}{{.metadata.creationTimestamp}}{{"\n"}}
  {{end}}'

  sx::k8s::cert::pick 'certificates.cert-manager.io' "${template}" sx::k8s_command::cert::renew "${@}"
}

function sx::k8s::cert::pick() {
  local -r resource="${1}"
  local -r template="${2}"
  local -r exec_fn="${3}"
  local -r query="${4:-}"
  local -r exact="${5:-}"
  local -r namespace="${6:-}"
  local -r all_namespaces="${7:-false}"
  local -r context="${8:-}"
  local -r selector="${9:-}"

  sx::k8s::validate_context "${context}"
  sx::k8s::ensure_api_access "${context}"

  if [ -n "${exact}" ]; then
    local -r ns="${namespace:-$(sx::k8s::current_namespace "${context}")}"

    "${exec_fn}" "${ns}" "${exact}" "${context}"
  elif sx::os::is_command_available 'fzf'; then
    local -r options="$(
      sx::k8s::cert::list "${resource}" "${template}" "${query}" "${namespace}" "${all_namespaces}" true "${context}" "${selector}"
    )"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No resources found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf --header-lines 1 ${SX_FZF_ARGS})"

    if [ -n "${selected}" ]; then
      local -r ns="$(echo "${selected}" | awk '{ print $1 }')"
      local -r name="$(echo "${selected}" | awk '{ print $2 }')"

      "${exec_fn}" "${ns}" "${name}" "${context}"
    fi
  else
    export PS3=$'\n''Please, choose the resource: '$'\n'

    local options
    readarray -t options < <(
      sx::k8s::cert::list "${resource}" "${template}" "${query}" "${namespace}" "${all_namespaces}" false "${context}" "${selector}"
    )

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No resources found'
    fi

    select selected in "${options[@]}"; do
      if [ -z "${selected}" ]; then
        sx::log::err "Invalid option \"${REPLY}\". Please, type the number of the desired option."
        continue
      fi

      local -r ns="$(echo "${selected}" | awk '{ print $1 }')"
      local -r name="$(echo "${selected}" | awk '{ print $2 }')"

      "${exec_fn}" "${ns}" "${name}" "${context}"
      break
    done
  fi
}

function sx::k8s::cert::list() {
  local -r resource="${1}"
  local -r template="${2}"
  local -r query="${3:-}"
  local -r namespace="${4:-}"
  local -r all_namespaces="${5:-false}"
  local -r print_header="${6:-false}"
  local -r context="${7:-}"
  local -r selector="${8:-}"

  if ${all_namespaces}; then
    local flags='--all-namespaces'
  elif [ -n "${namespace}" ]; then
    local flags="--namespace ${namespace}"
  else
    local flags=''
  fi

  if [ -n "${selector}" ]; then
    flags+=" --selector ${selector}"
  fi

  if [ -n "${context}" ]; then
    local -r context_flags="--context ${context}"
  else
    local -r context_flags=''
  fi

  if [ -n "${query}" ]; then
    local -r query_pattern="${query}"
  else
    local -r query_pattern='.*'
  fi

  local -r now="$(date '+%s')"

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  local -r result="$(
    sx::k8s::cli ${context_flags} get "${resource}" \
      ${flags} \
      --output='go-template' \
      --template="$(sx::k8s::clear_template "${template}")" 2>/dev/null \
      | sort -u \
      | grep -E "${query_pattern}" 2>/dev/null \
      | while IFS=',' read -r res_namespace res_name created_at; do
        local res_age="$(sx::k8s::age "${created_at}" "${now}")"

        echo "${res_namespace},${res_name},${res_age}"
      done
  )"

  if [ -z "${result}" ]; then
    echo
  elif ${print_header}; then
    local -r header='NAMESPACE,NAME,AGE'
    echo -e "${header}\n${result}" | column -t -s ','
  else
    echo -e "${result}" | column -t -s ','
  fi
}

function sx::k8s_command::cert::inspect() {
  local -r ns="${1:-}"
  local -r name="${2:-}"
  local -r context="${3:-}"

  if [ -n "${context}" ]; then
    local -r context_flags="--context ${context}"
  else
    local -r context_flags=''
  fi

  sx::log::info "Inspecting certificate in secret \"${ns}/${name}\"\n"

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  cmctl inspect secret "${name}" --namespace "${ns}" ${context_flags}
}

function sx::k8s_command::cert::status() {
  local -r ns="${1:-}"
  local -r name="${2:-}"
  local -r context="${3:-}"

  if [ -n "${context}" ]; then
    local -r context_flags="--context ${context}"
  else
    local -r context_flags=''
  fi

  sx::log::info "Fetching status for certificate \"${ns}/${name}\"\n"

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  cmctl status certificate "${name}" --namespace "${ns}" ${context_flags}
}

function sx::k8s_command::cert::renew() {
  local -r ns="${1:-}"
  local -r name="${2:-}"
  local -r context="${3:-}"

  if [ -n "${context}" ]; then
    local -r context_flags="--context ${context}"
  else
    local -r context_flags=''
  fi

  sx::log::info "Renewing certificate \"${ns}/${name}\"\n"

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  cmctl renew "${name}" --namespace "${ns}" ${context_flags}
}
