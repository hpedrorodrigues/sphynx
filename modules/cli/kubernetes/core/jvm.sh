#!/usr/bin/env bash

function sx::k8s::jvm() {
  sx::k8s::check_requirements

  local -r query="${1:-}"
  local -r selector="${2:-}"
  local -r namespace="${3:-}"
  local -r pod="${4:-}"
  local -r container="${5:-}"
  local -r heapdump="${6:-true}"
  local -r threaddump="${7:-false}"
  local -r output_dir="${8:-}"
  local -r all_namespaces="${9:-false}"
  local -r context="${10:-}"

  sx::k8s::validate_context "${context}"
  sx::k8s::ensure_api_access "${context}"

  if [ -n "${namespace}" ] && [ -n "${pod}" ] && [ -n "${container}" ]; then
    sx::k8s_command::jvm "${namespace}" "${pod}" "${container}" "${heapdump}" "${threaddump}" "${output_dir}" "${context}"
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

      sx::k8s_command::jvm "${ns}" "${name}" "${container_name}" "${heapdump}" "${threaddump}" "${output_dir}" "${context}"
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

      sx::k8s_command::jvm "${ns}" "${name}" "${container_name}" "${heapdump}" "${threaddump}" "${output_dir}" "${context}"
      break
    done
  fi
}

function sx::k8s_command::jvm() {
  local -r ns="${1}"
  local -r name="${2}"
  local -r container="${3}"
  local -r heapdump="${4}"
  local -r threaddump="${5}"
  local -r output_dir="${6:-}"
  local -r context="${7:-}"

  local -r pid="$(sx::k8s_command::jvm::detect_pid "${ns}" "${name}" "${container}" "${context}")"

  if [ -z "${pid}" ]; then
    sx::log::fatal "No JVM process found in pod \"${name}/${container}\""
  fi

  local -r timestamp="$(date '+%Y%m%d-%H%M%S')"

  if ${heapdump}; then
    sx::k8s_command::jvm::heapdump "${ns}" "${name}" "${container}" "${pid}" "${timestamp}" "${output_dir}" "${context}"
  fi

  if ${threaddump}; then
    sx::k8s_command::jvm::threaddump "${ns}" "${name}" "${container}" "${pid}" "${timestamp}" "${output_dir}" "${context}"
  fi
}

function sx::k8s_command::jvm::detect_pid() {
  local -r ns="${1}"
  local -r name="${2}"
  local -r container="${3}"
  local -r context="${4:-}"

  if [ -n "${context}" ]; then
    local -r context_flags="--context ${context}"
  else
    local -r context_flags=''
  fi

  # shellcheck disable=SC2016,SC2086  # expressions don't expand in single quotes; quote this to prevent word splitting
  local -r jcmd_pid="$(
    sx::k8s::cli ${context_flags} exec --namespace "${ns}" "${name}" --container "${container}" -- \
      sh -c 'jcmd 2>/dev/null | grep -v "jdk.jcmd" | head -1 | awk "{ print \$1 }"' 2>/dev/null \
      || true
  )"

  if [ -n "${jcmd_pid}" ]; then
    echo "${jcmd_pid}"
    return
  fi

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  local -r pgrep_pid="$(
    sx::k8s::cli ${context_flags} exec --namespace "${ns}" "${name}" --container "${container}" -- \
      pgrep -x java 2>/dev/null | head -1 \
      || true
  )"

  if [ -n "${pgrep_pid}" ]; then
    echo "${pgrep_pid}"
    return
  fi

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  local -r ps_pid="$(
    sx::k8s::cli ${context_flags} exec --namespace "${ns}" "${name}" --container "${container}" -- \
      sh -c "ps aux 2>/dev/null | grep '[j]ava' | head -1 | awk '{ print \$2 }'" 2>/dev/null \
      || true
  )"

  if [ -n "${ps_pid}" ]; then
    echo "${ps_pid}"
    return
  fi

  echo ''
}

function sx::k8s_command::jvm::heapdump() {
  local -r ns="${1}"
  local -r name="${2}"
  local -r container="${3}"
  local -r pid="${4}"
  local -r timestamp="${5}"
  local -r output_dir="${6:-}"
  local -r context="${7:-}"

  if [ -n "${context}" ]; then
    local -r context_flags="--context ${context}"
  else
    local -r context_flags=''
  fi

  local -r filename="heapdump-${name}-${timestamp}.hprof"
  local -r remote_file="/tmp/${filename}"

  if [ -n "${output_dir}" ]; then
    local -r local_file="${output_dir}/${filename}"
  else
    local -r local_file="./${filename}"
  fi

  sx::log::info "Generating heap dump for pod \"${name}/${container}\" (PID: ${pid})..."

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  if sx::k8s::cli ${context_flags} exec --namespace "${ns}" "${name}" --container "${container}" -- \
    jcmd "${pid}" 'GC.heap_dump' "${remote_file}" &>/dev/null; then

    sx::log::info "Heap dump generated in \"${remote_file}\" using \"jcmd\"."
  elif sx::k8s::cli ${context_flags} exec --namespace "${ns}" "${name}" --container "${container}" -- \
    jmap -dump:format=b,file="${remote_file}" "${pid}" &>/dev/null; then

    sx::log::info "Heap dump generated in \"${remote_file}\" using \"jmap\"."
  else
    sx::log::fatal "Failed to generate heap dump in pod \"${name}/${container}\". Tried: \"jcmd\" and \"jmap\"."
  fi

  sx::k8s::copy_from_pod "${ns}" "${name}" "${container}" "${remote_file}" "${local_file}" "${context}"

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  sx::k8s::cli ${context_flags} exec --namespace "${ns}" "${name}" --container "${container}" -- rm -f "${remote_file}" &>/dev/null || true

  sx::log::info "Heap dump saved to: ${local_file}."
}

function sx::k8s_command::jvm::threaddump() {
  local -r ns="${1}"
  local -r name="${2}"
  local -r container="${3}"
  local -r pid="${4}"
  local -r timestamp="${5}"
  local -r output_dir="${6:-}"
  local -r context="${7:-}"

  if [ -n "${context}" ]; then
    local -r context_flags="--context ${context}"
  else
    local -r context_flags=''
  fi

  local -r filename="threaddump-${name}-${timestamp}.txt"
  local -r remote_file="/tmp/${filename}"

  if [ -n "${output_dir}" ]; then
    local -r local_file="${output_dir}/${filename}"
  else
    local -r local_file="./${filename}"
  fi

  sx::log::info "Generating thread dump for pod \"${name}/${container}\" (PID: ${pid})..."

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  if sx::k8s::cli ${context_flags} exec --namespace "${ns}" "${name}" --container "${container}" -- \
    sh -c "jcmd ${pid} 'Thread.print' > ${remote_file} 2>/dev/null" &>/dev/null; then

    sx::log::info "Thread dump generated in \"${remote_file}\" using \"jcmd\"."

    local -r thread_dump_generated='true'
  elif sx::k8s::cli ${context_flags} exec --namespace "${ns}" "${name}" --container "${container}" -- \
    sh -c "jstack ${pid} > ${remote_file} 2>/dev/null" &>/dev/null; then

    sx::log::info "Thread dump generated in \"${remote_file}\" using \"jstack\"."

    local -r thread_dump_generated='true'
  elif sx::k8s::cli ${context_flags} exec --namespace "${ns}" "${name}" --container "${container}" -- \
    kill -3 "${pid}" &>/dev/null; then

    sx::log::info 'Thread dump triggered using "kill -3". Output will be in the JVM stdout/logs, not in a file.'

    local -r thread_dump_generated='false'
  else
    sx::log::fatal "Failed to generate thread dump in pod \"${name}/${container}\". Tried: \"jcmd\", \"jstack\", \"kill -3\"."
  fi

  if ${thread_dump_generated}; then
    sx::k8s::copy_from_pod "${ns}" "${name}" "${container}" "${remote_file}" "${local_file}" "${context}"

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    sx::k8s::cli ${context_flags} exec --namespace "${ns}" "${name}" --container "${container}" -- rm -f "${remote_file}" &>/dev/null || true

    sx::log::info "Thread dump saved to: ${local_file}."
  fi
}
