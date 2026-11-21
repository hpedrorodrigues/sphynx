#!/usr/bin/env bash

function sx::k8s::pods::resource_summary() {
  sx::k8s::check_requirements

  local -r query="${1:-}"
  local -r namespace="${2:-}"
  local -r all_namespaces="${3:-false}"
  local -r selector="${4:-}"
  local -r context="${5:-$(sx::k8s::current_context)}"

  sx::k8s::validate_context "${context}"
  sx::k8s::ensure_api_access "${context}"

  local flags
  readarray -t flags < <(sx::k8s::scope_flags "${namespace}" "${all_namespaces}" "${selector}" "${context}")

  local -r query_pattern="$(sx::string::lowercase "${query:-.*}")"

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

  local -r raw_pod_output="$(
    sx::k8s::cli get pods \
      "${flags[@]}" \
      --output go-template \
      --template="$(sx::k8s::clear_template "${template}")" \
      | sort -u \
      | sx::string::lowercase \
      | grep -E "${query_pattern}" 2>/dev/null
  )"
  local -r top_output="$(
    sx::k8s::cli top pods \
      "${flags[@]}" \
      --containers \
      --no-headers 2>/dev/null
  )"

  if [ -z "${raw_pod_output}" ] || [ -z "${top_output}" ]; then
    sx::log::fatal 'No pods found'
  fi

  local resources='NAMESPACE,POD,CONTAINER,CPU (USAGE),CPU (REQUEST),CPU (LIMIT),MEMORY (USAGE),MEMORY (REQUEST),MEMORY (LIMIT)\n\n'
  while IFS='' read -r pod_output; do
    local pod_namespace pod_name container_name container_top_output cpu_usage memory_usage
    pod_namespace="$(echo "${pod_output}" | awk -F ',' '{ print $1 }')"
    pod_name="$(echo "${pod_output}" | awk -F ',' '{ print $2 }')"
    container_name="$(echo "${pod_output}" | awk -F ',' '{ print $3 }')"

    if ${all_namespaces}; then
      container_top_output="$(
        awk -v pod_namespace="${pod_namespace}" -v pod_name="${pod_name}" -v container_name="${container_name}" \
          '$1 == pod_namespace && $2 == pod_name && $3 == container_name' <<<"${top_output}"
      )"
      cpu_usage="$(echo -e "${container_top_output}" | awk '{ print $4 }')"
      memory_usage="$(echo -e "${container_top_output}" | awk '{ print $5 }')"
    else
      container_top_output="$(
        awk -v pod_name="${pod_name}" -v container_name="${container_name}" \
          '$1 == pod_name && $2 == container_name' <<<"${top_output}"
      )"
      cpu_usage="$(echo -e "${container_top_output}" | awk '{ print $3 }')"
      memory_usage="$(echo -e "${container_top_output}" | awk '{ print $4 }')"
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

function sx::k8s::resource_summary::watch() {
  sx::k8s::check_requirements

  local -r interval="${1:-2}"
  local -r pods="${2:-false}"
  local -r query="${3:-}"
  local -r namespace="${4:-}"
  local -r all_namespaces="${5:-false}"
  local -r selector="${6:-}"
  local -r context="${7:-$(sx::k8s::current_context)}"

  sx::k8s::validate_context "${context}"
  sx::k8s::ensure_api_access "${context}"

  local args=()
  if ${pods}; then
    args+=(pods)

    if ${all_namespaces}; then
      args+=(--all-namespaces)
    elif [ -n "${namespace}" ]; then
      args+=(--namespace "${namespace}")
    fi

    if [ -n "${selector}" ]; then
      args+=(--selector "${selector}")
    fi
  else
    args+=(nodes)

    if [ -n "${selector}" ]; then
      args+=(--selector "${selector}")
    fi
  fi

  if [ -n "${query}" ]; then
    args+=("${query}")
  fi

  if [ -n "${context}" ]; then
    args+=(--context "${context}")
  fi

  if sx::os::is_command_available "${SPHYNX_EXEC_NAME}"; then
    local -r sphynx_command="${SPHYNX_EXEC_NAME}"
  else
    local -r sphynx_command="${SPHYNX_EXEC}"
  fi

  sx::os::watcher "${interval}" "${sphynx_command}" kubernetes resource-summary "${args[@]}"
}

function sx::k8s::nodes::resource_summary() {
  sx::k8s::check_requirements

  local -r query="${1:-}"
  local -r context="${2:-$(sx::k8s::current_context)}"
  local -r selector="${3:-}"

  sx::k8s::validate_context "${context}"
  sx::k8s::ensure_api_access "${context}"

  local flags=()
  if [ -n "${context}" ]; then
    flags+=(--context "${context}")
  fi

  if [ -n "${selector}" ]; then
    flags+=(--selector "${selector}")
  fi

  local -r query_pattern="$(sx::string::lowercase "${query:-.*}")"

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
    sx::k8s::cli "${flags[@]}" get nodes \
      --output go-template \
      --template="$(sx::k8s::clear_template "${template}")" \
      | sort -u \
      | sx::string::lowercase \
      | grep -E "${query_pattern}" 2>/dev/null
  )"
  local -r top_output="$(sx::k8s::cli "${flags[@]}" top nodes --no-headers 2>/dev/null)"

  local resources='NODE,CPU (USAGE),CPU (CAPACITY),MEMORY (USAGE),MEMORY (CAPACITY),RUNTIME,OS,IMAGE,ARCH,KERNEL\n\n'
  while IFS='' read -r node_output; do
    local node_name node_top_output cpu_usage memory_usage
    node_name="$(echo "${node_output}" | awk -F ',' '{ print $1 }')"
    node_top_output="$(awk -v node_name="${node_name}" '$1 == node_name' <<<"${top_output}")"

    cpu_usage="$(echo -e "${node_top_output}" | awk '{ print $2 }')"
    memory_usage="$(echo -e "${node_top_output}" | awk '{ print $4 }')"

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
