#!/usr/bin/env bash

function sx::k8s::port_forward() {
  sx::k8s::check_requirements

  local -r query="${1:-}"
  local -r namespace="${2:-}"
  local -r all_namespaces="${3:-false}"
  local -r random_port="${4:-false}"

  if sx::os::is_command_available 'fzf'; then
    local -r options="$(
      sx::k8s::resources_and_ports "${query}" "${namespace}" "${all_namespaces}"
    )"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No resources found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf ${SX_FZF_ARGS})"

    if [ -n "${selected}" ]; then
      local -r ns="$(echo "${selected}" | awk '{ print $1 }')"
      local -r kind="$(echo "${selected}" | awk '{ print $2 }')"
      local -r name="$(echo "${selected}" | awk '{ print $3 }')"
      local -r port="$(echo "${selected}" | awk '{ print $4 }')"

      sx::k8s_command::port_forward \
        "${ns}" \
        "${kind}" \
        "${name}" \
        "${port}" \
        "${random_port}"
    fi
  else
    export PS3=$'\n''Please, choose the resource: '$'\n'

    local options
    readarray -t options < <(
      sx::k8s::resources_and_ports "${query}" "${namespace}" "${all_namespaces}"
    )

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No resources found'
    fi

    select selected in "${options[@]}"; do
      local -r ns="$(echo "${selected}" | awk '{ print $1 }')"
      local -r kind="$(echo "${selected}" | awk '{ print $2 }')"
      local -r name="$(echo "${selected}" | awk '{ print $3 }')"
      local -r port="$(echo "${selected}" | awk '{ print $4 }')"

      sx::k8s_command::port_forward \
        "${ns}" \
        "${kind}" \
        "${name}" \
        "${port}" \
        "${random_port}"
      break
    done
  fi
}

function sx::k8s::resources_and_ports() {
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

  # shellcheck disable=SC2016  # expressions don't expand in single quotes
  local -r pods_template='
  {{range .items}}
    {{$namespace := .metadata.namespace}}
    {{$name := .metadata.name}}
    {{$kind := .kind}}
    {{range .spec.containers}}
      {{range .ports}}
        {{$namespace}}{{","}}{{$kind}}{{","}}{{$name}}{{","}}{{.containerPort}}{{"\n"}}
      {{end}}
    {{end}}
  {{end}}'
  # shellcheck disable=SC2016  # expressions don't expand in single quotes
  local -r services_template='
  {{range .items}}
    {{$namespace := .metadata.namespace}}
    {{$name := .metadata.name}}
    {{$kind := .kind}}
    {{range .spec.ports}}
      {{$namespace}}{{","}}{{$kind}}{{","}}{{$name}}{{","}}{{.port}}{{"\n"}}
    {{end}}
  {{end}}'
  # shellcheck disable=SC2016  # expressions don't expand in single quotes
  local -r deployments_template='
  {{range .items}}
    {{$namespace := .metadata.namespace}}
    {{$name := .metadata.name}}
    {{$kind := .kind}}
    {{range .spec.template.spec.containers}}
      {{range .ports}}
        {{$namespace}}{{","}}{{$kind}}{{","}}{{$name}}{{","}}{{.containerPort}}{{"\n"}}
      {{end}}
    {{end}}
  {{end}}'

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  local -r output="$(
    sx::k8s::cli get services \
      ${flags} \
      --output go-template \
      --template="$(sx::k8s::clear_template "${services_template}")"
    sx::k8s::cli get deployments \
      ${flags} \
      --output go-template \
      --template="$(sx::k8s::clear_template "${deployments_template}")"
    sx::k8s::cli get pods \
      ${flags} \
      --output go-template \
      --template="$(sx::k8s::clear_template "${pods_template}")"
  )"

  echo "${output}" \
    | sx::string::lowercase \
    | sort -u \
    | column -t -s ',' \
    | grep -E "${selector}" 2>/dev/null
}

function sx::k8s_command::port_forward() {
  local -r ns="${1:-}"
  local -r kind="${2:-}"
  local -r name="${3:-}"
  local -r port="${4:-}"
  local -r random_port="${5:-false}"

  if ${random_port}; then
    local -r local_port="$(shuf -i 10000-32767 -n 1)"
  else
    local -r local_port="${port}"
  fi

  if [ "${kind}" = 'pod' ]; then
    sx::log::info "Port forwarding to pod (${ns}/${name}:${port})\n"
  else
    sx::log::info "Port forwarding to a pod selected by the ${kind} (${ns}/${name})\n"
  fi

  sx::k8s::cli port-forward \
    --namespace "${ns}" \
    "${kind}/${name}" "${local_port}:${port}"
}
