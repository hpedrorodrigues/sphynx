#!/usr/bin/env bash

function sx::k8s::topology() {
  sx::k8s::check_requirements

  local -r query="${1:-}"
  local -r selector="${2:-}"
  local -r all_namespaces="${3:-false}"
  local -r show_resource_usage="${4:-false}"
  local -r show_labels="${5:-false}"
  local -r context="${6:-}"
  local -r namespace="${7:-}"

  sx::k8s::validate_context "${context}"
  sx::k8s::ensure_api_access "${context}"

  local context_flags=()
  if [ -n "${context}" ]; then
    context_flags+=(--context "${context}")
  fi

  local pod_flags=("${context_flags[@]}")
  if ${all_namespaces}; then
    pod_flags+=(--all-namespaces)
  elif [ -n "${namespace}" ]; then
    pod_flags+=(--namespace "${namespace}")
  fi

  if [ -n "${selector}" ]; then
    pod_flags+=(--selector "${selector}")
  fi

  if ${show_resource_usage}; then
    sx::require 'jq'
  fi

  local -r output_directory="$(mktemp -d)"

  sx::k8s::topology::collect_pods "${query}" "${pod_flags[@]}" >"${output_directory}/pods" &
  local -r pods_request="${!}"

  sx::k8s::topology::collect_nodes "${context_flags[@]}" >"${output_directory}/nodes" &
  local -r nodes_request="${!}"

  if ${show_resource_usage}; then
    sx::k8s::topology::collect_node_usage "${context_flags[@]}" >"${output_directory}/node-usage" &
    sx::k8s::topology::collect_pod_usage "${pod_flags[@]}" >"${output_directory}/pod-usage" &
  fi

  wait "${pods_request}" || true

  if ! [ -s "${output_directory}/pods" ]; then
    wait
    rm -r "${output_directory}"
    sx::log::fatal 'No resources found'
  fi

  if ${show_resource_usage}; then
    local node_names
    readarray -t node_names < <(
      awk -F ',' '$5 != "" { print $5 }' "${output_directory}/pods" | sort -u
    )

    (
      sx::k8s::topology::collect_storage "${#node_names[@]}" "${node_names[@]}" "${context_flags[@]}"
    ) >"${output_directory}/storage"
  fi

  if ! wait "${nodes_request}"; then
    wait
    rm -r "${output_directory}"
    sx::log::fatal 'Cannot list the nodes'
  fi

  wait

  local -r records="$(cat "${output_directory}"/*)"
  rm -r "${output_directory}"

  sx::k8s::topology::render "${show_resource_usage}" "${show_labels}" <<<"${records}"
}

function sx::k8s::topology::collect_pods() {
  local -r query="${1:-}"
  local -r flags=("${@:2}")

  local -r query_pattern="$(sx::string::lowercase "${query:-.*}")"

  sx::k8s::cli get pods \
    "${flags[@]}" \
    --output jsonpath='{range .items[*]}{.status.hostIP}{","}{.metadata.namespace}{","}{.metadata.name}{","}{.spec.nodeName}{","}{.status.phase}{"\n"}{end}' \
    | grep -E "${query_pattern}" 2>/dev/null \
    | sort -t ',' -k 2,2 -k 3,3 \
    | sed 's/^/pod,/'
}

function sx::k8s::topology::collect_nodes() {
  local -r flags=("${@}")

  # shellcheck disable=SC2016  # Expressions don't expand in single quotes
  local -r template='{{range .items}}node,{{.metadata.name}},{{range .status.addresses}}{{if eq .type "InternalIP"}}{{.address}} {{end}}{{end}},{{range $key, $value := .metadata.labels}}{{$key}}={{$value}};{{end}}{{"\n"}}{{end}}'

  sx::k8s::cli get nodes \
    "${flags[@]}" \
    --output go-template \
    --template "${template}"
}

function sx::k8s::topology::collect_node_usage() {
  local -r flags=("${@}")

  local output
  if ! output="$(sx::k8s::cli top nodes "${flags[@]}" --no-headers 2>/dev/null)"; then
    sx::log::err 'Cannot read the node metrics, so the node CPU and memory show as "Unknown"'
    return 0
  fi

  awk 'NF >= 5 { print "node-usage," $1 "," $2 "," $3 "," $4 "," $5 }' <<<"${output}"
}

function sx::k8s::topology::collect_pod_usage() {
  local -r flags=("${@}")

  local output
  if ! output="$(sx::k8s::cli top pods "${flags[@]}" --no-headers 2>/dev/null)"; then
    sx::log::err 'Cannot read the pod metrics, so the pod CPU and memory show as "Unknown"'
    return 0
  fi

  awk '
    NF == 4 { print "pod-usage," $1 "," $2 "," $3 "," $4 }
    NF == 3 { print "pod-usage,*," $1 "," $2 "," $3 }
  ' <<<"${output}"
}

function sx::k8s::topology::collect_storage() {
  local -r node_count="${1}"
  local -r node_names=("${@:2:node_count}")
  local -r flags=("${@:2+node_count}")
  local -r max_parallel_requests='8'

  local -r output_directory="$(mktemp -d)"

  local running_requests='0'
  local node_index='0'
  for node_name in "${node_names[@]}"; do
    sx::k8s::topology::collect_node_storage "${node_name}" "${flags[@]}" >"${output_directory}/${node_index}" &

    node_index="$((node_index + 1))"
    running_requests="$((running_requests + 1))"
    if [ "${running_requests}" -ge "${max_parallel_requests}" ]; then
      wait
      running_requests='0'
    fi
  done
  wait

  local output=''
  if [ "${node_index}" -gt 0 ]; then
    output="$(cat "${output_directory}"/*)"
  fi

  rm -r "${output_directory}"

  if [ -z "${output}" ]; then
    sx::log::err 'Cannot read the kubelet stats, so the ephemeral storage shows as "Unknown"'
    return 0
  fi

  echo "${output}"
}

function sx::k8s::topology::collect_node_storage() {
  local -r node_name="${1}"
  local -r flags=("${@:2}")

  # shellcheck disable=SC2016  # Expressions don't expand in single quotes
  local -r jq_program='
    def human_size:
      if . == null then "Unknown"
      elif . >= 1073741824 then "\((. / 107374182.4 | round) / 10)Gi"
      else "\(. / 1048576 | round)Mi"
      end;

    (.node.fs // {}) as $fs
    | (
      if $fs.usedBytes != null and ($fs.capacityBytes // 0) > 0
      then "\($fs.usedBytes * 100 / $fs.capacityBytes | round)%"
      else "Unknown"
      end
    ) as $percentage
    | "node-storage,\($node_name),\($fs.usedBytes | human_size),\($percentage)",
      (.pods[]? | "pod-storage,\(.podRef.namespace),\(.podRef.name),\(."ephemeral-storage".usedBytes | human_size)")
  '

  sx::k8s::cli get \
    "${flags[@]}" \
    --raw "/api/v1/nodes/${node_name}/proxy/stats/summary" \
    --request-timeout "${SX_K8S_REQUEST_TIMEOUT}" 2>/dev/null \
    | jq --raw-output --arg node_name "${node_name}" "${jq_program}" 2>/dev/null
}

function sx::k8s::topology::render() {
  local -r show_resource_usage="${1:-false}"
  local -r show_labels="${2:-false}"

  # shellcheck disable=SC2016  # Expressions don't expand in single quotes
  local -r awk_program='
    function or_unknown(value) {
      return value == "" ? "Unknown" : value
    }

    function pod_word(count) {
      return count == 1 ? "pod" : "pods"
    }

    function ip_sort_key(ip,    octets) {
      if (split(ip, octets, ".") == 4) {
        return sprintf("%03d.%03d.%03d.%03d", octets[1], octets[2], octets[3], octets[4])
      }

      return ip == "" ? "zzz" : ip
    }

    function sort_scheduled_nodes(    position, previous, current) {
      for (position = 2; position <= scheduled_node_count; position++) {
        current = scheduled_nodes[position]
        previous = position - 1

        while (previous >= 1 && node_sort_key[scheduled_nodes[previous]] > node_sort_key[current]) {
          scheduled_nodes[previous + 1] = scheduled_nodes[previous]
          previous--
        }

        scheduled_nodes[previous + 1] = current
      }
    }

    function print_pods(node,    position, pod, parts, key, row) {
      if (show_resources) {
        print "|-- CPU,MEM,EPH,STATE,NAMESPACE,NAME" | table_command
      } else {
        print "|-- STATE,NAMESPACE,NAME" | table_command
      }

      for (position = 1; position <= pod_count[node]; position++) {
        pod = pods[node, position]
        split(pod, parts, SUBSEP)
        key = parts[1] SUBSEP parts[2]

        row = pod_phase[node, position] "," parts[1] "," parts[2]
        if (show_resources) {
          if (!(key in pod_cpu)) {
            key = "*" SUBSEP parts[2]
          }

          row = or_unknown(pod_cpu[key]) "," or_unknown(pod_memory[key]) "," or_unknown(pod_storage[parts[1], parts[2]]) "," row
        }

        print "|-- " row | table_command
      }

      close(table_command)
    }

    function print_node(node,    label_count, label_list, position) {
      if (node == "") {
        printf "> Unscheduled (%d %s)\n", pod_count[node], pod_word(pod_count[node])
      } else {
        printf "> %s (%s | %d %s)\n", or_unknown(node_ip[node]), node, pod_count[node], pod_word(pod_count[node])

        if (show_resources) {
          printf "> CPU (%s | %s) -|- MEM (%s | %s) -|- EPH (%s | %s)\n", \
            or_unknown(node_cpu[node]), or_unknown(node_cpu_percentage[node]), \
            or_unknown(node_memory[node]), or_unknown(node_memory_percentage[node]), \
            or_unknown(node_storage[node]), or_unknown(node_storage_percentage[node])
        }

        if (show_labels && node_labels[node] != "") {
          print ""
          label_count = split(node_labels[node], label_list, ";")
          for (position = 1; position <= label_count; position++) {
            if (label_list[position] != "") {
              print "* " label_list[position]
            }
          }
        }
      }

      print ""
      fflush()
      print_pods(node)
      print ""
    }

    BEGIN {
      FS = ","
      table_command = "column -t -s ,"
      show_resources = (show_resources == "true")
      show_labels = (show_labels == "true")
    }

    $1 == "pod" {
      node = $5
      if (node != "") {
        if (!(node in pod_count)) {
          scheduled_nodes[++scheduled_node_count] = node
        }

        if (pod_host_ip[node] == "" && $2 != "") {
          pod_host_ip[node] = $2
        }
      }

      pod_count[node]++
      pods[node, pod_count[node]] = $3 SUBSEP $4
      pod_phase[node, pod_count[node]] = $6
    }

    $1 == "node" {
      known_node_count++
      split($3, node_addresses, " ")
      node_address[$2] = node_addresses[1]
      node_labels[$2] = $4
    }

    $1 == "node-usage" {
      node_cpu[$2] = $3
      node_cpu_percentage[$2] = $4
      node_memory[$2] = $5
      node_memory_percentage[$2] = $6
    }

    $1 == "pod-usage" {
      pod_cpu[$2, $3] = $4
      pod_memory[$2, $3] = $5
    }

    $1 == "node-storage" {
      node_storage[$2] = $3
      node_storage_percentage[$2] = $4
    }

    $1 == "pod-storage" {
      pod_storage[$2, $3] = $4
    }

    END {
      for (position = 1; position <= scheduled_node_count; position++) {
        node = scheduled_nodes[position]
        node_ip[node] = node_address[node] != "" ? node_address[node] : pod_host_ip[node]
        node_sort_key[node] = ip_sort_key(node_ip[node]) "," node
      }

      sort_scheduled_nodes()

      for (position = 1; position <= scheduled_node_count; position++) {
        print_node(scheduled_nodes[position])
      }

      if ("" in pod_count) {
        print_node("")
      }

      total_node_count = known_node_count > scheduled_node_count ? known_node_count : scheduled_node_count

      print ""
      printf "%d out of %d nodes\n", scheduled_node_count, total_node_count
    }
  '

  awk \
    -v show_resources="${show_resource_usage}" \
    -v show_labels="${show_labels}" \
    "${awk_program}"
}
