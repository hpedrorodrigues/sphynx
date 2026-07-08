#!/usr/bin/env bash

function sx::k8s::prof::check_requirements() {
  if ! sx::os::is_command_available 'kubectl-prof'; then
    sx::log::fatal 'The kubectl plugin "prof" is not installed. For more details, see: https://github.com/josepdcs/kubectl-prof.'
  fi
}

function sx::k8s::prof() {
  sx::k8s::check_requirements
  sx::k8s::prof::check_requirements
  sx::k8s::ensure_api_access

  local -r query="${1:-}"
  local -r selector="${2:-}"
  local -r namespace="${3:-}"
  local -r pod="${4:-}"
  local -r container="${5:-}"
  local -r all_namespaces="${6:-false}"
  local -r non_root="${7:-false}"
  local -r keep_jobs="${8:-false}"
  local -r timeout="${9:-10m}"
  local -r image="${10:-}"
  local -r extra_flags="${11:-}"

  if [ -n "${namespace}" ] && [ -n "${pod}" ] && [ -n "${container}" ]; then
    sx::k8s_command::prof "${namespace}" "${pod}" "${container}" "${non_root}" "${keep_jobs}" "${timeout}" "${image}" "${extra_flags}"
  elif sx::os::is_command_available 'fzf'; then
    local -r options="$(
      sx::k8s::running_pods "${query}" "${selector}" "${namespace}" "${all_namespaces}" true
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

      sx::k8s_command::prof "${ns}" "${name}" "${container_name}" "${non_root}" "${keep_jobs}" "${timeout}" "${image}" "${extra_flags}"
    fi
  else
    export PS3=$'\n''Please, choose the pod: '$'\n'

    local options
    readarray -t options < <(
      sx::k8s::running_pods "${query}" "${selector}" "${namespace}" "${all_namespaces}"
    )

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No running pods found'
    fi

    select selected in "${options[@]}"; do
      local -r ns="$(echo "${selected}" | awk '{ print $1 }')"
      local -r name="$(echo "${selected}" | awk '{ print $2 }')"
      local -r container_name="$(echo "${selected}" | awk '{ print $3 }')"

      sx::k8s_command::prof "${ns}" "${name}" "${container_name}" "${non_root}" "${keep_jobs}" "${timeout}" "${image}" "${extra_flags}"
      break
    done
  fi
}

function sx::k8s_command::prof() {
  local -r ns="${1}"
  local -r name="${2}"
  local -r container="${3}"
  local -r non_root="${4:-false}"
  local -r keep_jobs="${5:-false}"
  local -r timeout="${6:-10m}"
  local -r image="${7:-}"
  local -r extra_flags="${8:-}"

  if ${non_root}; then
    sx::k8s_command::prof::fix_permissions "${ns}" "${name}" "${container}" "${image}"
  fi

  sx::log::info "Profiling pod \"${name}/${container}\"...\n"

  # kubectl-prof can hang forever when the agent dies without emitting a final event
  if sx::os::is_command_available 'timeout'; then
    local -r timeout_cmd="timeout --foreground ${timeout}"
  else
    local -r timeout_cmd=''
  fi

  local exit_code=0

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  ${timeout_cmd} ${SX_K8SCTL} prof "${name}" \
    --namespace "${ns}" \
    --target-container-name "${container}" \
    ${extra_flags} || exit_code="${?}"

  if [ "${exit_code}" -ne 0 ]; then
    if [ "${exit_code}" -eq 124 ]; then
      sx::log::err "Profiling timed out after ${timeout}. For longer profiles, pass a bigger \"--timeout\"."
    else
      sx::log::err 'Profiling failed. If the target runs as non-root, retry with "--non-root".'
      sx::log::err 'If a previous attempt failed mid-profile, restart the workload first.'
    fi

    if ${keep_jobs}; then
      sx::log::info "Keeping profiling jobs. Inspect with: kubectl get jobs --namespace ${ns} | grep kubectl-prof"
    else
      sx::k8s_command::prof::cleanup_orphaned_jobs "${ns}" "${name}"
    fi

    exit "${exit_code}"
  fi
}

function sx::k8s_command::prof::cleanup_orphaned_jobs() {
  local -r ns="${1}"
  local -r name="${2}"

  # kubectl-prof only deletes its job on success. This run's jobs are matched by the target pod UID
  local -r pod_uid="$(
    sx::k8s::cli get pod "${name}" \
      --namespace "${ns}" \
      --output jsonpath='{.metadata.uid}' 2>/dev/null
  )"

  if [ -z "${pod_uid}" ]; then
    return 0
  fi

  local -r jobs="$(
    sx::k8s::cli get jobs --namespace "${ns}" --output name 2>/dev/null \
      | grep 'kubectl-prof' \
      || true
  )"

  local job
  for job in ${jobs}; do
    if sx::k8s::cli get "${job}" --namespace "${ns}" --output yaml 2>/dev/null | grep -q "${pod_uid}"; then
      sx::k8s::cli delete "${job}" --namespace "${ns}" --wait='false' &>/dev/null || true

      sx::log::info "Deleted orphaned profiling job \"${job#job.batch/}\"."
    fi
  done
}

function sx::k8s_command::prof::fix_permissions() {
  local -r ns="${1}"
  local -r name="${2}"
  local -r container="${3}"
  local -r image="${4:-ghcr.io/hpedrorodrigues/debug}"

  local -r debugger_container="profiler-fix-$(uuidgen | cut -d '-' -f 1 | tr '[:upper:]' '[:lower:]')"
  local -r custom_profile_path="$(mktemp -t partial_container_spec || echo '/tmp/partial_container_spec.yaml')"

  # https://github.com/kubernetes/enhancements/blob/c68dfb941894fc8859a951fe47a60b2161300b88/keps/sig-cli/4292-kubectl-debug-custom-profile/README.md
  cat >"${custom_profile_path}" <<-EOF
  securityContext:
    runAsGroup: 0
    runAsUser: 0
    runAsNonRoot: false
	EOF

  sx::log::info "Making the profiler shared dir writable in pod \"${name}/${container}\"..."

  # Pre-create the shared dir as 0777 so non-root targets can write the profiling output
  # (the agent adopts existing dirs), and drop leftovers from failed runs to avoid ETXTBSY
  # shellcheck disable=SC2016  # expressions don't expand in single quotes
  sx::k8s::cli debug "${name}" \
    --attach=false \
    --profile 'sysadmin' \
    --custom="${custom_profile_path}" \
    --namespace "${ns}" \
    --target "${container}" \
    --image "${image}" \
    --container "${debugger_container}" \
    --quiet \
    -- sh -c 'dir="/proc/1/root/kubectl-prof"; mkdir -p "${dir}" && chmod 0777 "${dir}" && rm -rf "${dir}/async-profiler"'

  local exit_code=''

  for _ in $(seq 1 60); do
    exit_code="$(
      sx::k8s::cli get pod "${name}" \
        --namespace "${ns}" \
        --output "jsonpath={.status.ephemeralContainerStatuses[?(@.name==\"${debugger_container}\")].state.terminated.exitCode}" \
        2>/dev/null || true
    )"

    if [ -n "${exit_code}" ]; then
      break
    fi

    sleep 1
  done

  if [ "${exit_code}" != '0' ]; then
    sx::log::fatal "Failed to make the profiler shared dir writable in pod \"${name}/${container}\""
  fi
}
