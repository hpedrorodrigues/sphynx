#!/usr/bin/env bash

function sx::jvm::fiberdump() {
  local -r query="${1:-}"
  local -r selector="${2:-}"
  local -r namespace="${3:-}"
  local -r pod="${4:-}"
  local -r container="${5:-}"
  local -r all_namespaces="${6:-false}"
  local -r context="${7:-}"
  local -r force="${8:-false}"

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

  # A fiber dump only needs SIGUSR1, so it never runs the JDK tooling and never needs a JDK container.
  local pid
  pid="$(sx::jvm::resolve_pid "${ns}" "${name}" "${container_name}" "${context}")"
  readonly pid

  local -r timestamp="$(date '+%Y%m%d-%H%M%S')"

  sx::jvm_command::fiberdump "${ns}" "${name}" "${container_name}" "${pid}" "${timestamp}" "${context}" "${force}"
}

function sx::jvm_command::fiberdump() {
  local -r ns="${1}"
  local -r name="${2}"
  local -r container="${3}"
  local -r pid="${4}"
  local -r timestamp="${5}"
  local -r context="${6:-}"
  local -r force="${7:-false}"

  local -r context_flags="$(sx::jvm::context_flags "${context}")"

  local -r filename="fiberdump-${name}-${timestamp}.txt"
  local -r local_file="./${filename}"

  # Safety gate: SIGUSR1's default disposition is to terminate the process, so it is
  # only safe to send when the JVM has registered a USR1 handler (as Cats Effect 3
  # does). /proc/<pid>/status "SigCgt" is the caught-signals bitmask; USR1 is signal
  # 10, i.e. bit 9 (0x200). Refuse unless the bit is set, or --force is given.
  if ! ${force}; then
    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r sigcgt="$(
      sx::k8s::cli ${context_flags} exec --namespace "${ns}" "${name}" --container "${container}" -- \
        sh -c "grep '^SigCgt' /proc/${pid}/status" 2>/dev/null | awk '{ print $2 }' \
        || true
    )"

    if [ -z "${sigcgt}" ] || ! ((0x${sigcgt} & 0x200)); then
      sx::log::fatal "Refusing to send SIGUSR1 to pod \"${name}/${container}\": the JVM does not appear to handle USR1 (SigCgt=${sigcgt:-unknown}), so the signal could terminate it.\nFiber dumps require a Cats Effect 3 application. Re-run with \"--force\" to override."
    fi
  fi

  sx::log::info "Generating fiber dump for pod \"${name}/${container}\" (PID: ${pid})..."

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  if ! sx::k8s::cli ${context_flags} exec --namespace "${ns}" "${name}" --container "${container}" -- \
    sh -c "kill -s USR1 ${pid}" &>/dev/null; then

    sx::log::fatal "Failed to trigger fiber dump (SIGUSR1) in pod \"${name}/${container}\"."
  fi

  if sx::jvm::capture_dump_from_logs "${ns}" "${name}" "${container}" "${local_file}" "${context}" '^cats.effect.IOFiber@' '^Global: enqueued'; then
    sx::log::info "Fiber dump triggered using SIGUSR1, captured from the pod logs and saved to: ${local_file}."
  else
    sx::log::info 'Fiber dump triggered using SIGUSR1. Output is in the JVM stderr/logs; it could not be auto-captured to a file (is this a Cats Effect 3 app with active fibers?).'
  fi
}
