#!/usr/bin/env bash

function sx::k8s::network::dump_traffic() {
  sx::k8s::check_requirements

  local -r query="${1:-}"
  local -r selector="${2:-}"
  local -r namespace="${3:-}"
  local -r pod="${4:-}"
  local -r container="${5:-}"
  local -r duration="${6:-30}"
  local -r output_dir="${7:-}"
  local -r all_namespaces="${8:-false}"
  local -r extra_flags="${9:-}"
  local -r image="${10:-}"
  local -r context="${11:-}"

  sx::k8s::validate_context "${context}"
  sx::k8s::ensure_api_access "${context}"

  if [ -n "${namespace}" ] && [ -n "${pod}" ] && [ -n "${container}" ]; then
    sx::k8s_command::network::dump_traffic "${namespace}" "${pod}" "${container}" "${duration}" "${output_dir}" "${extra_flags}" "${image}" "${context}"
  elif sx::os::is_command_available 'fzf'; then
    local -r options="$(
      sx::k8s::running_pods "${query}" "${selector}" "${namespace}" "${all_namespaces}" true "${context}"
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

      sx::k8s_command::network::dump_traffic "${ns}" "${name}" "${container_name}" "${duration}" "${output_dir}" "${extra_flags}" "${image}" "${context}"
    fi
  else
    export PS3=$'\n''Please, choose the pod: '$'\n'

    local options
    readarray -t options < <(
      sx::k8s::running_pods "${query}" "${selector}" "${namespace}" "${all_namespaces}" false "${context}"
    )

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No running pods found'
    fi

    select selected in "${options[@]}"; do
      if [ -z "${selected}" ]; then
        sx::log::err "Invalid option \"${REPLY}\". Please, type the number of the desired option."
        continue
      fi

      local -r ns="$(echo "${selected}" | awk '{ print $1 }')"
      local -r name="$(echo "${selected}" | awk '{ print $2 }')"
      local -r container_name="$(echo "${selected}" | awk '{ print $3 }')"

      sx::k8s_command::network::dump_traffic "${ns}" "${name}" "${container_name}" "${duration}" "${output_dir}" "${extra_flags}" "${image}" "${context}"
      break
    done
  fi
}

function sx::k8s_command::network::dump_traffic() {
  local -r ns="${1}"
  local -r name="${2}"
  local -r container="${3}"
  local -r duration="${4}"
  local -r output_dir="${5:-}"
  local -r extra_flags="${6:-}"
  local -r image="${7:-ghcr.io/hpedrorodrigues/debug}"
  local -r context="${8:-}"

  if [ -n "${context}" ]; then
    local -r context_flags="--context ${context}"
  else
    local -r context_flags=''
  fi

  local -r timestamp="$(date '+%Y%m%d-%H%M%S')"
  local -r filename="traffic-${name}-${timestamp}.pcap"

  if [ -n "${output_dir}" ]; then
    local -r local_file="${output_dir}/${filename}"
  else
    local -r local_file="./${filename}"
  fi

  local -r debugger_container="debugger-$(uuidgen | cut -d '-' -f 1 | tr '[:upper:]' '[:lower:]')"
  local -r custom_profile_path="$(mktemp -t partial_container_spec || echo '/tmp/partial_container_spec.yaml')"

  # https://github.com/kubernetes/enhancements/blob/c68dfb941894fc8859a951fe47a60b2161300b88/keps/sig-cli/4292-kubectl-debug-custom-profile/README.md
  cat >"${custom_profile_path}" <<-EOF
  securityContext:
    runAsGroup: 0
    runAsUser: 0
    runAsNonRoot: false
	EOF

  sx::log::info "Capturing network traffic from pod \"${name}(${debugger_container})\" using debug image \"${image}\" for ${duration}s...\n"

  # Create the ephemeral debug container without attaching (--attach=false). It avoids the known issue where
  # kubectl debug's attach mechanism hangs after the container process terminates. We then use kubectl exec
  # to run the capture, which exits cleanly.
  # shellcheck disable=SC2086  # quote this to prevent word splitting
  sx::k8s::cli ${context_flags} debug "${name}" \
    --attach=false \
    --profile 'sysadmin' \
    --custom="${custom_profile_path}" \
    --namespace "${ns}" \
    --target "${container}" \
    --image "${image}" \
    --container "${debugger_container}" \
    --quiet \
    -- sleep $((duration + 30))

  # Wait for the ephemeral container to be running
  local container_running=false
  local started_at=''

  for _ in $(seq 1 60); do
    # shellcheck disable=SC2086  # quote this to prevent word splitting
    started_at="$(
      sx::k8s::cli ${context_flags} get pod "${name}" \
        --namespace "${ns}" \
        --output "jsonpath={.status.ephemeralContainerStatuses[?(@.name==\"${debugger_container}\")].state.running.startedAt}" \
        2>/dev/null || true
    )"

    if [ -n "${started_at}" ]; then
      container_running=true
      break
    fi

    sleep 1
  done

  if ! ${container_running}; then
    sx::log::fatal "Timed out waiting for debug container to start in pod \"${name}\"."
  fi

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  sx::k8s::cli ${context_flags} exec "${name}" \
    --namespace "${ns}" \
    --container "${debugger_container}" \
    -- sh -c "
      if command -v tshark >/dev/null 2>&1; then
        timeout ${duration} tshark -w - ${extra_flags} 2>/dev/null; true
      elif command -v tcpdump >/dev/null 2>&1; then
        timeout ${duration} tcpdump -w - ${extra_flags} 2>/dev/null; true
      else
        exit 1
      fi
    " >"${local_file}"

  if [ ! -s "${local_file}" ]; then
    rm -f "${local_file}"
    sx::log::fatal "Failed to capture network traffic from pod \"${name}\". Ensure the debug image has tshark or tcpdump."
  fi

  sx::log::info "Capture saved to: ${local_file}."
}
