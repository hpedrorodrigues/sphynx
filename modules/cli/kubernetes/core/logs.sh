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
    {{$pod := .}}
    {{$namespace := .metadata.namespace}}
    {{$name := .metadata.name}}
    {{$phase := .status.phase}}
    {{$created_at := .metadata.creationTimestamp}}
    {{range .status.containerStatuses}}
      {{$namespace}}{{","}}{{$name}}{{","}}{{.name}}{{","}}{{$phase}}{{","}}{{.restartCount}}{{","}}{{$created_at}}{{"\n"}}
    {{end}}
    {{range $i, $status := .status.initContainerStatuses}}
      {{$spec := index $pod.spec.initContainers $i}}
      {{if eq $spec.restartPolicy "Always"}}
        {{$namespace}}{{","}}{{$name}}{{","}}{{$status.name}}{{","}}{{$phase}}{{","}}{{$status.restartCount}}{{","}}{{$created_at}}{{","}} (Sidecar Container){{"\n"}}
      {{else}}
        {{$namespace}}{{","}}{{$name}}{{","}}{{$status.name}}{{","}}{{$phase}}{{","}}{{$status.restartCount}}{{","}}{{$created_at}}{{","}} (Init Container){{"\n"}}
      {{end}}
    {{end}}
  {{end}}'

  local -r now="$(date '+%s')"

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  local -r result="$(
    sx::k8s::cli get pods \
      ${flags} \
      --output go-template \
      --template="$(sx::k8s::clear_template "${template}")" 2>/dev/null \
      | sort -u \
      | grep -vE 'Pending\|ContainerCreating\|Terminating\|CreateContainerConfigError' \
      | grep -E "${selector}" 2>/dev/null \
      | while IFS=',' read -r pod_namespace pod_name container_name pod_status restart_count created_at description; do
        local pod_age="$(sx::k8s::age "${created_at}" "${now}")"

        echo "${pod_namespace},${pod_name},${container_name},${pod_status},${restart_count},${pod_age},${description}"
      done
  )"

  if [ -z "${result}" ]; then
    echo
  elif ${print_header}; then
    local -r header='NAMESPACE,POD NAME,CONTAINER NAME,STATUS,RESTARTS,AGE,DESCRIPTION'
    echo -e "${header}\n${result}" | column -t -s ','
  else
    echo -e "${result}" | column -t -s ','
  fi
}
