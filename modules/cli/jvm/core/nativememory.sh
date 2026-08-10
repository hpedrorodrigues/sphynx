#!/usr/bin/env bash

function sx::jvm::nativememory() {
  local -r query="${1:-}"
  local -r selector="${2:-}"
  local -r namespace="${3:-}"
  local -r pod="${4:-}"
  local -r container="${5:-}"
  local -r level="${6:-summary}"
  local -r all_namespaces="${7:-false}"
  local -r context="${8:-}"
  local -r image="${9:-}"

  sx::k8s::check_requirements
  sx::jvm_command::nativememory::validate_level "${level}"
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

  sx::jvm_command::nativememory "${ns}" "${name}" "${container_name}" "${pid}" "${timestamp}" "${context}" "${jdk_container}" "${level}"
}

function sx::jvm_command::nativememory::validate_level() {
  local -r level="${1:-}"

  # "jcmd" takes more Native Memory Tracking arguments than these two (baseline, summary.diff),
  # but they need a second invocation to be of any use, so only the report levels are accepted.
  if [ "${level}" != 'summary' ] && [ "${level}" != 'detail' ]; then
    sx::log::fatal "Invalid native memory tracking level \"${level}\"!\n\nAvailable levels:\nsummary\ndetail"
  fi
}

function sx::jvm_command::nativememory() {
  local -r ns="${1}"
  local -r name="${2}"
  local -r container="${3}"
  local -r pid="${4}"
  local -r timestamp="${5}"
  local -r context="${6:-}"
  local -r jdk_container="${7:-}"
  local -r level="${8}"

  local -r context_flags="$(sx::jvm::context_flags "${context}")"

  local -r filename="nativememory-${name}-${timestamp}.txt"
  local -r local_file="./${filename}"

  sx::log::info "Generating native memory report (${level}) for pod \"${name}/${container}\" (PID: ${pid})..."

  # Native Memory Tracking is only reachable through the attach mechanism, so "jcmd" is the
  # only tool that can produce it, with no "jmap"/"jstack"-style alternative to fall back to.
  # It answers on the stdout of the attaching process, as "Thread.print" does, so the report
  # streams straight into the local file and nothing is written in the pod.
  if [ -n "${jdk_container}" ]; then
    if ! sx::jvm::jdk_exec "${ns}" "${name}" "${jdk_container}" "${pid}" "${context}" \
      jcmd "${pid}" 'VM.native_memory' "${level}" 'scale=MB' 2>/dev/null >"${local_file}" \
      || [ ! -s "${local_file}" ]; then

      rm -f "${local_file}"

      sx::log::fatal "Failed to generate the native memory report in pod \"${name}/${container}\" from the JDK container \"${jdk_container}\". Does the image ship \"jcmd\", and is it as new as the target JVM?"
    fi

    sx::log::info 'Native memory report generated using "jcmd" from the JDK container.'
  else
    # shellcheck disable=SC2086  # quote this to prevent word splitting
    if ! sx::k8s::cli ${context_flags} exec --namespace "${ns}" "${name}" --container "${container}" -- \
      jcmd "${pid}" 'VM.native_memory' "${level}" 'scale=MB' 2>/dev/null >"${local_file}" \
      || [ ! -s "${local_file}" ]; then

      rm -f "${local_file}"

      sx::log::fatal "Failed to generate the native memory report in pod \"${name}/${container}\": \"jcmd\" is not available (common on JRE-only/distroless images). Re-run with \"--image eclipse-temurin:21-jdk\" to run the JDK tooling from an ephemeral container."
    fi

    sx::log::info 'Native memory report generated using "jcmd".'
  fi

  # "jcmd" exits 0 and still prints the PID line even when the JVM refuses the command, so a
  # run against a JVM started without "-XX:NativeMemoryTracking" writes a two-line file and
  # looks successful ("Native memory tracking is not enabled"). The same match covers a JVM
  # that only tracks a summary refusing "detail" ("Detail tracking is not enabled").
  if grep -qi 'not enabled' "${local_file}"; then
    local -r refusal="$(grep -i -m 1 'not enabled' "${local_file}")"

    rm -f "${local_file}"

    sx::log::fatal "The JVM of pod \"${name}/${container}\" refused the native memory report: ${refusal}\nStart it with \"-XX:NativeMemoryTracking=${level}\" to enable it."
  fi

  sx::log::info "Native memory report saved to: ${local_file}."
}
