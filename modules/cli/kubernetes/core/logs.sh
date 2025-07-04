#!/usr/bin/env bash

function sx::k8s::logs() {
  sx::k8s::check_requirements
  sx::k8s::ensure_api_access

  local -r query="${1:-}"
  local -r namespace="${2:-}"
  local -r pod="${3:-}"
  local -r container="${4:-}"
  local -r all_namespaces="${5:-false}"
  local -r previous_log="${6:-false}"

  if [ -n "${namespace}" ] && [ -n "${pod}" ] && [ -n "${container}" ]; then
    sx::k8s_command::logs "${namespace}" "${pod}" "${container}" "${previous_log}"
  elif sx::os::is_command_available 'fzf'; then
    local -r options="$(
      sx::k8s_command::pod::list "${query}" "${namespace}" "${all_namespaces}" true
    )"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No running pods found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf --header-lines 1 ${SX_FZF_ARGS})"

    if [ -n "${selected}" ]; then
      local -r ns="$(echo "${selected}" | awk '{ print $1 }')"
      local -r name="$(echo "${selected}" | awk '{ print $2 }')"
      local -r container_name="$(echo "${selected}" | awk '{ print $3 }')"

      sx::k8s_command::logs "${ns}" "${name}" "${container_name}" "${previous_log}"
    fi
  else
    export PS3=$'\n''Please, choose the pod: '$'\n'

    local options
    readarray -t options < <(
      sx::k8s_command::pod::list "${query}" "${namespace}" "${all_namespaces}"
    )

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No running pods found'
    fi

    select selected in "${options[@]}"; do
      local -r ns="$(echo "${selected}" | awk '{ print $1 }')"
      local -r name="$(echo "${selected}" | awk '{ print $2 }')"
      local -r container_name="$(echo "${selected}" | awk '{ print $3 }')"

      sx::k8s_command::logs "${ns}" "${name}" "${container_name}" "${previous_log}"
      break
    done
  fi
}

function sx::k8s_command::logs() {
  local -r ns="${1}"
  local -r name="${2}"
  local -r container="${3}"
  local -r previous_log="${4}"

  local flags=''
  if ${previous_log}; then
    flags+=' --previous'
  fi

  sx::log::info "Tailing logs from pod \"${name}/${container}\"\n"

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  sx::k8s::cli logs "${name}" \
    --namespace "${ns}" \
    --container "${container}" \
    --follow \
    ${flags}
}

function sx::k8s_command::pod::list() {
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
    {{$createdAt := .metadata.creationTimestamp}}
    {{range .spec.initContainers}}
      {{if eq .restartPolicy "Always"}}
        {{$namespace}}{{","}}{{$name}}{{","}}{{.name}}{{", (Sidecar Container)"}}{{"\n"}}
      {{else}}
        {{$namespace}}{{","}}{{$name}}{{","}}{{.name}}{{", (Init Container)"}}{{"\n"}}
      {{end}}
    {{end}}
    {{range .spec.containers}}
      {{$namespace}}{{","}}{{$name}}{{","}}{{.name}}{{"\n"}}
    {{end}}
  {{end}}'

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  local -r simple_pods_output="$(
    sx::k8s::cli get pods \
      ${flags} 2>/dev/null \
      | grep -E "${selector}"
  )"

  local -r header='NAMESPACE,POD NAME,CONTAINER NAME,STATUS,RESTARTS,AGE,DESCRIPTION'

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

        if echo "${pod_status}" | grep -q 'Pending\|ContainerCreating\|Terminating\|CreateContainerConfigError'; then
          continue
        fi

        local pod_namespace="$(echo "${templated_pod_line}" | awk '{ print $1 }')"
        local container_name="$(echo "${templated_pod_line}" | awk '{ print $3 }')"
        local description="$(echo "${templated_pod_line}" | awk '{ print $4 " " $5 }')"
        local pod_restarts_count="$(echo -e "${simple_pod_line}" | awk '{ print $4 }')"

        if echo "${simple_pod_line}" | grep -q '(\|)'; then
          local pod_age="$(echo -e "${simple_pod_line}" | awk '{ print $7 }')"
        else
          local pod_age="$(echo -e "${simple_pod_line}" | awk '{ print $5 }')"
        fi

        echo "${pod_namespace},${pod_name},${container_name},${pod_status},${pod_restarts_count},${pod_age},${description}"
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
