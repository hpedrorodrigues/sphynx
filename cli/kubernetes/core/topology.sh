#!/usr/bin/env bash

function sx::k8s::topology() {
  sx::k8s::check_requirements
  sx::k8s::ensure_api_access

  local -r query="${1:-}"
  local -r selector="${2:-}"
  local -r all_namespaces="${3:-false}"
  local -r show_resource_usage="${4:-false}"
  local -r show_labels="${5:-false}"

  # shellcheck disable=SC2086  # Double quote to prevent globbing and word splitting
  local -r assignments="$(
    sx::k8s::topology::assignments "${query}" "${selector}" "${all_namespaces}"
  )"

  if [ -z "${assignments}" ]; then
    sx::log::fatal 'No resources found'
  fi

  local -r instances="$(sx::k8s::cli get nodes --output wide --no-headers --show-labels)"
  local -r n_instances="$(echo "${instances}" | wc -l | tr -d ' ')"

  local instance_ips
  # References:
  # - https://www.madboa.com/geek/sort-addr
  readarray -t instance_ips < <(
    echo "${assignments}" | cut -d ',' -f 1 | sort -u -V
  )

  if ${show_resource_usage}; then
    local -r top_nodes="$(sx::k8s::cli top nodes --no-headers 2>/dev/null)"
    # shellcheck disable=SC2086  # Double quote to prevent globbing and word splitting
    local -r top_pods="$(sx::k8s::topology::top_pods "${all_namespaces}" "${selector}")"

    # shellcheck disable=SC2068  # Double quote array expansions
    for ip in ${instance_ips[@]}; do
      sx::k8s::instance_info "${ip}" "${top_nodes}" "${top_pods}" "${instances}" "${show_labels}"
      sx::k8s::pods_info "${ip}" "${assignments}" "${top_nodes}" "${top_pods}" "${all_namespaces}"
    done
  else
    # shellcheck disable=SC2068  # Double quote array expansions
    for ip in ${instance_ips[@]}; do
      local instance_name="$(echo "${assignments}" | grep "${ip}" | cut -d ',' -f 4 | head -n 1)"
      local instance_labels="$(echo "${instances}" | grep "${instance_name}" | awk '{ print $13 }')"

      if [ -z "${instance_name}" ]; then
        instance_name='Name not available'
      fi

      echo "> ${ip} (${instance_name})"

      if ${show_labels} && [ -n "${instance_labels}" ]; then
        echo
        IFS=',' read -ra labels <<<"${instance_labels}"
        for label in "${labels[@]}"; do
          echo "* ${label}"
        done
      fi

      echo
      echo -e "|-- STATE,NAMESPACE,NAME\n$(echo "${assignments}" | grep "${ip}" | awk -F ',' '{ print $5 "," $2 "," $3 }' | xargs -I % echo "|-- %")\n" | column -t -s ','
      echo
    done
  fi

  if [ -n "${n_instances}" ]; then
    echo
    local -r n_referenced_instances="${#instance_ips[@]}"
    local -r total_instances="$(
      sx::math::max "${n_referenced_instances}" "${n_instances}"
    )"
    echo "${n_referenced_instances} out of ${total_instances} nodes"
  fi
}

function sx::k8s::topology::assignments() {
  local -r query="${1:-}"
  local -r selector="${2:-}"
  local -r all_namespaces="${3:-false}"

  local flags=''
  if ${all_namespaces}; then
    flags+=' --all-namespaces'
  fi

  if [ -n "${selector}" ]; then
    flags+=" --selector ${selector}"
  fi

  if [ -n "${query}" ]; then
    local -r text_filter="$(echo "${query}" | sx::string::lowercase)"
  else
    local -r text_filter='.*'
  fi

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  sx::k8s::cli get pods \
    ${flags} \
    --output jsonpath='{range .items[*]}{.status.hostIP}{","}{.metadata.namespace}{","}{.metadata.name}{","}{.spec.nodeName}{","}{.status.phase}{"\n"}{end}' \
    --sort-by '{.status.hostIP}' \
    | grep -E "${text_filter}" 2>/dev/null
}

function sx::k8s::topology::top_pods() {
  local -r all_namespaces="${1:-false}"
  local -r selector="${2:-}"

  local flags=''
  if ${all_namespaces}; then
    flags+=' --all-namespaces'
  fi

  if [ -n "${selector}" ]; then
    flags+=" --selector ${selector}"
  fi

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  sx::k8s::cli top pods \
    ${flags} \
    --no-headers 2>/dev/null
}

function sx::k8s::instance_info() {
  local -r ip="${1}"
  local -r topn="${2}"
  local -r topp="${3}"
  local -r instances="${4}"
  local -r show_labels="${5}"

  local -r current_instance_name="$(echo -e "${instances}" | grep "${ip}" | awk '{ print $1 }')"
  if [ -z "${current_instance_name}" ]; then
    local -r instance_name='Name not available'
  else
    local -r instance_name="${current_instance_name}"
  fi

  local -r instance_labels="$(echo "${instances}" | grep "${instance_name}" | awk '{ print $13 }')"
  local -r instance_usage="$(echo -e "${topn}" | grep "${instance_name}")"

  local -r cpu_usage="$(echo "${instance_usage}" | awk '{ print $2 }')"
  local -r cpu_percentage="$(echo "${instance_usage}" | awk '{ print $3 }')"

  local -r memory_usage="$(echo "${instance_usage}" | awk '{ print $4 }')"
  local -r memory_percentage="$(echo "${instance_usage}" | awk '{ print $5 }')"

  echo "> ${ip} (${instance_name})"
  echo "> CPU (${cpu_usage} | ${cpu_percentage}) -|- MEM (${memory_usage} | ${memory_percentage})"

  if ${show_labels} && [ -n "${instance_labels}" ]; then
    echo
    IFS=',' read -ra labels <<<"${instance_labels}"
    for label in "${labels[@]}"; do
      echo "* ${label}"
    done
  fi

  echo
}

function sx::k8s::pods_info() {
  local -r ip="${1}"
  local -r assignments="${2}"
  local -r topn="${3}"
  local -r topp="${4}"
  local -r all_ns="${5}"

  local pods
  readarray -t pods < <(
    echo "${assignments}" | grep "${ip}" | cut -d ',' -f 3 | sort -u
  )

  local resource_usage='|-- CPU,MEM,STATE,NAMESPACE,NAME\n'
  # shellcheck disable=SC2068  # Double quote array expansions
  for pod in ${pods[@]}; do
    local pod_info="$(echo "${topp}" | grep "${pod}")"
    local pod_state="$(echo "${assignments}" | grep "${pod}" | cut -d ',' -f 5)"

    local pod_ns="$(echo "${assignments}" | grep "${pod}" | cut -d ',' -f 2)"

    local cpu_position="$(${all_ns} && echo '3' || echo '2')"
    local cpu_usage="$(echo "${pod_info}" | awk "{ print \$${cpu_position} }")"

    local memory_position="$(${all_ns} && echo '4' || echo '3')"
    local memory_usage="$(echo "${pod_info}" | awk "{ print \$${memory_position} }")"

    local final_cpu_usage="$([ -z "${cpu_usage}" ] && echo 'Unknown' || echo "${cpu_usage}")"
    local final_mem_usage="$([ -z "${memory_usage}" ] && echo 'Unknown' || echo "${memory_usage}")"

    resource_usage+="|-- ${final_cpu_usage},${final_mem_usage},${pod_state},${pod_ns},${pod}\n"
  done

  echo -e "${resource_usage}" | column -t -s ','
  echo
}
