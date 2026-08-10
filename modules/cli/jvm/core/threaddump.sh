#!/usr/bin/env bash

function sx::jvm::threaddump() {
  local -r query="${1:-}"
  local -r selector="${2:-}"
  local -r namespace="${3:-}"
  local -r pod="${4:-}"
  local -r container="${5:-}"
  local -r all_namespaces="${6:-false}"
  local -r context="${7:-}"
  local -r image="${8:-}"

  sx::k8s::check_requirements
  sx::k8s::validate_context "${context}"
  sx::k8s::ensure_api_access "${context}"

  local target
  target="$(
    sx::jvm::resolve_target "${query}" "${selector}" "${namespace}" "${pod}" "${container}" "${all_namespaces}" "${context}"
  )"

  if [ -z "${target}" ]; then
    return 0
  fi

  local ns name container_name
  IFS=',' read -r ns name container_name <<<"${target}"
  readonly ns name container_name

  local jdk_container=''
  if [ -n "${image}" ]; then
    jdk_container="$(sx::jvm::jdk_container_name)"

    # shellcheck disable=SC2064  # expand the arguments now so the trap stops the right container
    trap "sx::jvm::stop_jdk_container '${ns}' '${name}' '${jdk_container}' '${context}'" EXIT

    sx::jvm::start_jdk_container "${ns}" "${name}" "${container_name}" "${jdk_container}" "${image}" "${context}"
  fi
  readonly jdk_container

  local pid
  pid="$(sx::jvm::resolve_pid "${ns}" "${name}" "${container_name}" "${context}" "${jdk_container}")"
  readonly pid

  local -r timestamp="$(date '+%Y%m%d-%H%M%S')"

  sx::jvm_command::threaddump "${ns}" "${name}" "${container_name}" "${pid}" "${timestamp}" "${context}" "${jdk_container}"
}

function sx::jvm_command::threaddump() {
  local -r ns="${1}"
  local -r name="${2}"
  local -r container="${3}"
  local -r pid="${4}"
  local -r timestamp="${5}"
  local -r context="${6:-}"
  local -r jdk_container="${7:-}"

  local -r context_flags="$(sx::jvm::context_flags "${context}")"

  local -r filename="threaddump-${name}-${timestamp}.txt"
  local -r remote_file="/tmp/${filename}"
  local -r local_file="./${filename}"

  sx::log::info "Generating thread dump for pod \"${name}/${container}\" (PID: ${pid})..."

  # The JDK tooling answers on the stdout of the attaching process, which is the JDK container
  # here, so the dump streams straight into the local file. Nothing is written in the pod.
  if [ -n "${jdk_container}" ]; then
    if sx::jvm::jdk_exec "${ns}" "${name}" "${jdk_container}" "${pid}" "${context}" \
      jcmd "${pid}" 'Thread.print' 2>/dev/null >"${local_file}"; then

      sx::log::info 'Thread dump generated using "jcmd" from the JDK container.'
    elif sx::jvm::jdk_exec "${ns}" "${name}" "${jdk_container}" "${pid}" "${context}" \
      jstack "${pid}" 2>/dev/null >"${local_file}"; then

      sx::log::info 'Thread dump generated using "jstack" from the JDK container.'
    else
      sx::log::fatal "Failed to generate thread dump in pod \"${name}/${container}\" from the JDK container \"${jdk_container}\". Does the image ship \"jcmd\" or \"jstack\", and is it as new as the target JVM?"
    fi

    if [ ! -s "${local_file}" ]; then
      rm -f "${local_file}"

      sx::log::fatal "The JDK container \"${jdk_container}\" returned an empty thread dump for pod \"${name}/${container}\"."
    fi

    sx::log::info "Thread dump saved to: ${local_file}."

    return
  fi

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
    sh -c "kill -3 ${pid}" &>/dev/null; then

    if sx::jvm::capture_dump_from_logs "${ns}" "${name}" "${container}" "${local_file}" "${context}" 'Full thread dump' '^JNI global refs:'; then
      sx::log::info "Thread dump triggered using \"kill -3\", captured from the pod logs and saved to: ${local_file}."
    else
      sx::log::info 'Thread dump triggered using "kill -3". Output is in the JVM stdout/logs; it could not be auto-captured to a file.'
    fi

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
