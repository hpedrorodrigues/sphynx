#!/usr/bin/env bash

function sx::jvm::heapdump() {
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

  sx::jvm_command::heapdump "${ns}" "${name}" "${container_name}" "${pid}" "${timestamp}" "${context}" "${jdk_container}"
}

function sx::jvm_command::heapdump() {
  local -r ns="${1}"
  local -r name="${2}"
  local -r container="${3}"
  local -r pid="${4}"
  local -r timestamp="${5}"
  local -r context="${6:-}"
  local -r jdk_container="${7:-}"

  local -r context_flags="$(sx::jvm::context_flags "${context}")"

  local -r filename="heapdump-${name}-${timestamp}.hprof"
  local -r remote_file="/tmp/${filename}"
  local -r local_file="./${filename}"

  sx::log::info "Generating heap dump for pod \"${name}/${container}\" (PID: ${pid})..."

  if [ -n "${jdk_container}" ]; then
    # The dump is always written by the JVM itself, so "${remote_file}" is a path in the target
    # container. The JDK container reads the very same file through the root of the JVM process.
    local -r source_container="${jdk_container}"
    local -r source_file="/proc/${pid}/root${remote_file}"

    if sx::jvm::jdk_exec "${ns}" "${name}" "${jdk_container}" "${pid}" "${context}" \
      jcmd "${pid}" 'GC.heap_dump' "${remote_file}" &>/dev/null; then

      sx::log::info "Heap dump generated in \"${remote_file}\" using \"jcmd\" from the JDK container."
    elif sx::jvm::jdk_exec "${ns}" "${name}" "${jdk_container}" "${pid}" "${context}" \
      jmap "-dump:format=b,file=${remote_file}" "${pid}" &>/dev/null; then

      sx::log::info "Heap dump generated in \"${remote_file}\" using \"jmap\" from the JDK container."
    else
      sx::log::fatal "Failed to generate heap dump in pod \"${name}/${container}\" from the JDK container \"${jdk_container}\". Does the image ship \"jcmd\" or \"jmap\", and is it as new as the target JVM?"
    fi
  else
    local -r source_container="${container}"
    local -r source_file="${remote_file}"

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    if sx::k8s::cli ${context_flags} exec --namespace "${ns}" "${name}" --container "${container}" -- \
      jcmd "${pid}" 'GC.heap_dump' "${remote_file}" &>/dev/null; then

      sx::log::info "Heap dump generated in \"${remote_file}\" using \"jcmd\"."
    elif sx::k8s::cli ${context_flags} exec --namespace "${ns}" "${name}" --container "${container}" -- \
      jmap -dump:format=b,file="${remote_file}" "${pid}" &>/dev/null; then

      sx::log::info "Heap dump generated in \"${remote_file}\" using \"jmap\"."
    else
      sx::log::fatal "Failed to generate heap dump in pod \"${name}/${container}\": neither \"jcmd\" nor \"jmap\" is available (common on JRE-only/distroless images). Re-run with \"--image eclipse-temurin:21-jdk\" to run the JDK tooling from an ephemeral container."
    fi
  fi

  local copied='true'
  sx::jvm::copy_dump "${ns}" "${name}" "${source_container}" "${source_file}" "${local_file}" "${context}" || copied='false'

  # Always drop the dump from the pod, a failed copy leaves hundreds of megabytes behind otherwise
  # shellcheck disable=SC2086  # quote this to prevent word splitting
  sx::k8s::cli ${context_flags} exec --namespace "${ns}" "${name}" --container "${source_container}" -- rm -f "${source_file}" &>/dev/null || true

  if ! ${copied}; then
    sx::log::fatal "Failed to copy the heap dump out of pod \"${name}/${source_container}\"."
  fi

  sx::log::info "Heap dump saved to: ${local_file}."
}
