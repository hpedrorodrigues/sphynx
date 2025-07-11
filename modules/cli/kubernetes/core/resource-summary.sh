#!/usr/bin/env bash

function sx::k8s::pods::resource_summary() {
  sx::k8s::check_requirements
  sx::k8s::ensure_api_access

  local -r query="${1:-}"
  local -r namespace="${2:-}"
  local -r all_namespaces="${3:-false}"
  local -r filter="${4:-}"

  if ${all_namespaces}; then
    local flags='--all-namespaces'
  elif [ -n "${namespace}" ]; then
    local flags="--namespace ${namespace}"
  else
    local flags=''
  fi

  if [ -n "${filter}" ]; then
    flags+=" --selector ${filter}"
  fi

  if [ -n "${query}" ]; then
    local -r selector="$(echo "${query}" | sx::string::lowercase)"
  else
    local -r selector='.*'
  fi

  # shellcheck disable=SC2016  # Expressions don't expand in single quotes, use double quotes for that
  local -r template='
  {{range .items}}
    {{$namespace := .metadata.namespace}}
    {{$name := .metadata.name}}
    {{range .spec.containers}}
      {{$namespace}}{{","}}
      {{$name}}{{","}}
      {{.name}}{{",_cpu_usage_,"}}
      {{.resources.requests.cpu}}{{","}}
      {{.resources.limits.cpu}}{{",_memory_usage_,"}}
      {{.resources.requests.memory}}{{","}}
      {{.resources.limits.memory}}{{"\n"}}
    {{end}}
    {{range .spec.initContainers}}
      {{if eq .restartPolicy "Always"}}
        {{$namespace}}{{","}}
        {{$name}}{{","}}
        {{.name}}{{",_cpu_usage_,"}}
        {{.resources.requests.cpu}}{{","}}
        {{.resources.limits.cpu}}{{",_memory_usage_,"}}
        {{.resources.requests.memory}}{{","}}
        {{.resources.limits.memory}}{{"\n"}}
      {{end}}
    {{end}}
  {{end}}'

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  local -r raw_pod_output="$(
    sx::k8s::cli get pods \
      ${flags} \
      --output go-template \
      --template="$(sx::k8s::clear_template "${template}")" \
      | sort -u \
      | sx::string::lowercase \
      | grep -E "${selector}" 2>/dev/null
  )"
  # shellcheck disable=SC2086  # quote this to prevent word splitting
  local -r top_output="$(
    sx::k8s::cli top pods \
      ${flags} \
      --containers \
      --no-headers 2>/dev/null
  )"

  if [ -z "${raw_pod_output}" ] || [ -z "${top_output}" ]; then
    sx::log::fatal 'No pods found'
  fi

  local resources='NAMESPACE,POD,CONTAINER,CPU (USAGE),CPU (REQUEST),CPU (LIMIT),MEMORY (USAGE),MEMORY (REQUEST),MEMORY (LIMIT)\n\n'
  while IFS='' read -r pod_output; do
    local pod_name="$(echo "${pod_output}" | awk -F ',' '{ print $2 }')"
    local container_name="$(echo "${pod_output}" | grep "${pod_name}" | awk -F ',' '{ print $3 }')"
    local container_top_output="$(echo -e "${top_output}" | grep "${pod_name} " | grep " ${container_name} ")"

    if ${all_namespaces}; then
      local cpu_usage="$(echo -e "${container_top_output}" | awk '{ print $4 }')"
      local memory_usage="$(echo -e "${container_top_output}" | awk '{ print $5 }')"
    else
      local cpu_usage="$(echo -e "${container_top_output}" | awk '{ print $3 }')"
      local memory_usage="$(echo -e "${container_top_output}" | awk '{ print $4 }')"
    fi

    if [ -z "${cpu_usage}" ]; then
      local cpu='<unknown>'
    else
      local cpu="${cpu_usage}"
    fi

    if [ -z "${memory_usage}" ]; then
      local memory='<unknown>'
    else
      local memory="${memory_usage}"
    fi

    resources+="$(echo -e "${pod_output}" | sed "s/_cpu_usage_/${cpu}/g" | sed "s/_memory_usage_/${memory}/g")\n"
  done < <(echo -e "${raw_pod_output}")

  echo -e "${resources}" | column -t -s ','
}

function sx::k8s::nodes::resource_summary() {
  sx::k8s::check_requirements
  sx::k8s::ensure_api_access

  local -r query="${1:-}"

  if [ -n "${query}" ]; then
    local -r selector="$(echo "${query}" | sx::string::lowercase)"
  else
    local -r selector='.*'
  fi

  # shellcheck disable=SC2016  # Expressions don't expand in single quotes, use double quotes for that
  local -r template='
  {{range .items}}
    {{.metadata.name}}{{",_cpu_usage_,"}}
    {{.status.capacity.cpu}}{{",_memory_usage_,"}}
    {{.status.capacity.memory}}{{","}}
    {{.status.nodeInfo.containerRuntimeVersion}}{{","}}
    {{.status.nodeInfo.operatingSystem}}{{","}}
    {{.status.nodeInfo.osImage}}{{","}}
    {{.status.nodeInfo.architecture}}{{","}}
    {{.status.nodeInfo.kernelVersion}}{{"\n"}}
  {{end}}'

  local -r raw_node_output="$(
    sx::k8s::cli get nodes \
      --output go-template \
      --template="$(sx::k8s::clear_template "${template}")" \
      | sort -u \
      | sx::string::lowercase \
      | grep -E "${selector}" 2>/dev/null
  )"
  local -r top_output="$(sx::k8s::cli top nodes --no-headers 2>/dev/null)"

  local resources='NODE,CPU (USAGE),CPU (CAPACITY),MEMORY (USAGE),MEMORY (CAPACITY),RUNTIME,OS,IMAGE,ARCH,KERNEL\n\n'
  while IFS='' read -r node_output; do
    local node_name="$(echo "${node_output}" | awk -F ',' '{ print $1 }')"
    local node_top_output="$(echo -e "${top_output}" | grep "${node_name}")"

    local cpu_usage="$(echo -e "${node_top_output}" | awk '{ print $2 }')"
    local memory_usage="$(echo -e "${node_top_output}" | awk '{ print $4 }')"

    if [ -z "${cpu_usage}" ]; then
      local cpu='<unknown>'
    else
      local cpu="${cpu_usage}"
    fi

    if [ -z "${memory_usage}" ]; then
      local memory='<unknown>'
    else
      local memory="${memory_usage}"
    fi

    resources+="$(echo -e "${node_output}" | sed "s/_cpu_usage_/${cpu}/g" | sed "s/_memory_usage_/${memory}/g")\n"
  done < <(echo -e "${raw_node_output}")

  echo -e "${resources}" | column -t -s ','
}
