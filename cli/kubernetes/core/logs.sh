#!/usr/bin/env bash

function sx::k8s::logs() {
  sx::k8s::check_requirements

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
      sx::k8s::pods "${query}" "${namespace}" "${all_namespaces}"
    )"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No running pods found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf ${SX_FZF_ARGS})"

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
      sx::k8s::pods "${query}" "${namespace}" "${all_namespaces}"
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

# This is a slightly different version of function "sx::k8s::running_pods"
# available in the shared file
function sx::k8s::pods() {
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

  # shellcheck disable=SC2016  # Expressions don't expand in single quotes, use double quotes for that
  local -r template='
  {{range .items}}
    {{if ne .status.phase "Pending"}}
      {{$namespace := .metadata.namespace}}
      {{$name := .metadata.name}}
      {{$createdAt := .metadata.creationTimestamp}}
      {{$phase := .status.phase}}
      {{range .spec.initContainers}}
        {{$namespace}}{{","}}{{$name}}{{","}}{{.name}}{{","}}{{$phase}}{{","}}{{$createdAt}}{{", (Init Container)"}}{{"\n"}}
      {{end}}
      {{range .spec.containers}}
        {{$namespace}}{{","}}{{$name}}{{","}}{{.name}}{{","}}{{$phase}}{{","}}{{$createdAt}}{{"\n"}}
      {{end}}
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
