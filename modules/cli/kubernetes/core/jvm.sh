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
  local -r fiberdump="${8:-false}"
  local -r output_dir="${9:-}"
  local -r all_namespaces="${10:-false}"
  local -r context="${11:-}"
  local -r force="${12:-false}"
  local -r jdk="${13:-false}"
  local -r jdk_image="${14:-}"

  sx::k8s::validate_context "${context}"
  sx::k8s::ensure_api_access "${context}"

  if [ -n "${namespace}" ] && [ -n "${pod}" ] && [ -n "${container}" ]; then
    sx::k8s_command::jvm "${namespace}" "${pod}" "${container}" "${heapdump}" "${threaddump}" "${fiberdump}" "${output_dir}" "${context}" "${force}" "${jdk}" "${jdk_image}"
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

      sx::k8s_command::jvm "${ns}" "${name}" "${container_name}" "${heapdump}" "${threaddump}" "${fiberdump}" "${output_dir}" "${context}" "${force}" "${jdk}" "${jdk_image}"
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

      sx::k8s_command::jvm "${ns}" "${name}" "${container_name}" "${heapdump}" "${threaddump}" "${fiberdump}" "${output_dir}" "${context}" "${force}" "${jdk}" "${jdk_image}"
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
  local -r fiberdump="${6}"
  local -r output_dir="${7:-}"
  local -r context="${8:-}"
  local -r force="${9:-false}"
  local -r jdk="${10:-false}"
  local -r jdk_image="${11:-}"

  local jdk_container=''
  if ${jdk}; then
    if ${heapdump} || ${threaddump}; then
      jdk_container="jdk-$(uuidgen | cut -d '-' -f 1 | tr '[:upper:]' '[:lower:]')"

      # shellcheck disable=SC2064  # expand the arguments now so the trap stops the right container
      trap "sx::k8s_command::jvm::stop_jdk_container '${ns}' '${name}' '${jdk_container}' '${context}'" EXIT

      sx::k8s_command::jvm::start_jdk_container "${ns}" "${name}" "${container}" "${jdk_container}" "${jdk_image}" "${context}"
    else
      sx::log::info 'Ignoring "--jdk": fiber dumps only need SIGUSR1, no JDK tooling.'
    fi
  fi
  readonly jdk_container

  local pid
  pid="$(sx::k8s_command::jvm::detect_pid "${ns}" "${name}" "${container}" "${context}")"

  # Images without a shell answer no "kubectl exec", so fall back to the JDK container, which
  # sees the same processes as the target container.
  if [ -z "${pid}" ] && [ -n "${jdk_container}" ]; then
    pid="$(sx::k8s_command::jvm::detect_pid "${ns}" "${name}" "${jdk_container}" "${context}")"
  fi

  if [ -z "${pid}" ]; then
    sx::log::fatal "No JVM process found in pod \"${name}/${container}\""
  fi
  readonly pid

  if [ -n "${jdk_container}" ]; then
    local preflight=''

    if ! preflight="$(sx::k8s_command::jvm::jdk_exec "${ns}" "${name}" "${jdk_container}" "${pid}" "${context}" true 2>&1)"; then
      sx::log::fatal "The JDK container \"${jdk_container}\" cannot reach the JVM of pod \"${name}/${container}\": ${preflight}"
    fi
  fi

  local -r timestamp="$(date '+%Y%m%d-%H%M%S')"

  if ${heapdump}; then
    sx::k8s_command::jvm::heapdump "${ns}" "${name}" "${container}" "${pid}" "${timestamp}" "${output_dir}" "${context}" "${jdk_container}"
  fi

  if ${threaddump}; then
    sx::k8s_command::jvm::threaddump "${ns}" "${name}" "${container}" "${pid}" "${timestamp}" "${output_dir}" "${context}" "${jdk_container}"
  fi

  if ${fiberdump}; then
    sx::k8s_command::jvm::fiberdump "${ns}" "${name}" "${container}" "${pid}" "${timestamp}" "${output_dir}" "${context}" "${force}"
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

  # Last resort: scan /proc for a process whose comm is "java". Works on minimal JRE images that ship none of "jcmd", "pgrep" or "ps".
  # shellcheck disable=SC2016,SC2086  # expressions don't expand in single quotes; quote this to prevent word splitting
  local -r proc_pid="$(
    sx::k8s::cli ${context_flags} exec --namespace "${ns}" "${name}" --container "${container}" -- \
      sh -c 'for process in /proc/[0-9]*; do [ -r "${process}/comm" ] && [ "$(cat "${process}/comm" 2>/dev/null)" = java ] && { echo "${process##*/}"; break; }; done' 2>/dev/null \
      || true
  )"

  if [ -n "${proc_pid}" ]; then
    echo "${proc_pid}"
    return
  fi

  echo ''
}

function sx::k8s_command::jvm::start_jdk_container() {
  local -r ns="${1}"
  local -r name="${2}"
  local -r container="${3}"
  local -r jdk_container="${4}"
  local -r image="${5:-eclipse-temurin:21-jdk}"
  local -r context="${6:-}"

  if [ -n "${context}" ]; then
    local -r context_flags="--context ${context}"
  else
    local -r context_flags=''
  fi

  local -r custom_profile_path="$(mktemp -t partial_container_spec || echo '/tmp/partial_container_spec.yaml')"

  # https://github.com/kubernetes/enhancements/blob/c68dfb941894fc8859a951fe47a60b2161300b88/keps/sig-cli/4292-kubectl-debug-custom-profile/README.md
  cat >"${custom_profile_path}" <<-EOF
  securityContext:
    runAsGroup: 0
    runAsUser: 0
    runAsNonRoot: false
	EOF

  sx::log::info "Attaching JDK container \"${jdk_container}\" to pod \"${name}/${container}\" using image \"${image}\"..."

  # "--target" puts the JDK container in the process namespace of the target container, so the JVM
  # keeps the same PID on both sides and the JDK tooling can attach to it. The container is created
  # detached (--attach=false) and waits for the sentinel file written by stop_jdk_container, giving
  # up on its own after 15 minutes if this command dies before it can stop it.
  # shellcheck disable=SC2016,SC2086  # expressions don't expand in single quotes; quote this to prevent word splitting
  sx::k8s::cli ${context_flags} debug "${name}" \
    --attach=false \
    --profile 'sysadmin' \
    --custom="${custom_profile_path}" \
    --namespace "${ns}" \
    --target "${container}" \
    --image "${image}" \
    --container "${jdk_container}" \
    --quiet \
    -- sh -c 'i=0; while [ ! -e /run/sx-jvm-stop ] && [ "${i}" -lt 900 ]; do i=$((i + 1)); sleep 1; done'

  local started_at=''

  for _ in $(seq 1 60); do
    # shellcheck disable=SC2086  # quote this to prevent word splitting
    started_at="$(
      sx::k8s::cli ${context_flags} get pod "${name}" \
        --namespace "${ns}" \
        --output "jsonpath={.status.ephemeralContainerStatuses[?(@.name==\"${jdk_container}\")].state.running.startedAt}" \
        2>/dev/null || true
    )"

    if [ -n "${started_at}" ]; then
      return 0
    fi

    sleep 1
  done

  sx::log::fatal "Timed out waiting for the JDK container \"${jdk_container}\" to start in pod \"${name}\". Is the image \"${image}\" pullable from this cluster?"
}

function sx::k8s_command::jvm::stop_jdk_container() {
  local -r ns="${1}"
  local -r name="${2}"
  local -r jdk_container="${3}"
  local -r context="${4:-}"

  if [ -z "${jdk_container}" ]; then
    return 0
  fi

  if [ -n "${context}" ]; then
    local -r context_flags="--context ${context}"
  else
    local -r context_flags=''
  fi

  # The JDK container shares the process namespace of the target container, where PID 1 is the JVM
  # itself, so nothing in there can be signalled. It watches for this sentinel file instead.
  # An ephemeral container cannot be removed from the pod, it stays until the pod is recreated.
  # shellcheck disable=SC2086  # quote this to prevent word splitting
  sx::k8s::cli ${context_flags} exec --namespace "${ns}" "${name}" --container "${jdk_container}" -- \
    touch /run/sx-jvm-stop &>/dev/null || true
}

function sx::k8s_command::jvm::jdk_exec() {
  local -r ns="${1}"
  local -r name="${2}"
  local -r jdk_container="${3}"
  local -r pid="${4}"
  local -r context="${5:-}"
  shift 5

  if [ -n "${context}" ]; then
    local -r context_flags="--context ${context}"
  else
    local -r context_flags=''
  fi

  # The JVM creates its attach socket at "/tmp/.java_pid<pid>" inside its own mount namespace, and
  # the JDK only looks for it under "/proc/<pid>/root" when the PID differs from the one in the
  # target namespace, which is not the case here. So bind "/tmp" to the "/tmp" of the JVM to make
  # both ends agree on the path. HotSpot also refuses an attach handshake coming from another
  # user, root included, hence the drop to the credentials of the JVM before running the tool.
  # shellcheck disable=SC2016  # expressions don't expand in single quotes
  local -r payload='
    pid="${1}"
    shift

    if [ "$(cat "/proc/${pid}/comm" 2>/dev/null)" != java ]; then
      echo "the container runtime did not share the process namespace with the target container" >&2
      exit 97
    fi

    uid="$(grep -m 1 ^Uid: "/proc/${pid}/status" | tr -s "\t " " " | cut -d " " -f 2)"
    gid="$(grep -m 1 ^Gid: "/proc/${pid}/status" | tr -s "\t " " " | cut -d " " -f 2)"

    mount --bind "/proc/${pid}/root/tmp" /tmp 2>/dev/null \
      || { rm -rf /tmp && ln -s "/proc/${pid}/root/tmp" /tmp; }

    if [ "${uid}" != 0 ] && command -v setpriv >/dev/null 2>&1; then
      exec setpriv --reuid "${uid}" --regid "${gid}" --clear-groups "${@}"
    fi

    exec "${@}"
  '

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  sx::k8s::cli ${context_flags} exec --namespace "${ns}" "${name}" --container "${jdk_container}" -- \
    sh -c "${payload}" 'sx-jvm' "${pid}" "${@}"
}

function sx::k8s_command::jvm::copy_dump() {
  local -r ns="${1}"
  local -r name="${2}"
  local -r container="${3}"
  local -r remote_file="${4}"
  local -r local_file="${5}"
  local -r context="${6:-}"

  if [ -n "${context}" ]; then
    local -r context_flags="--context ${context}"
  else
    local -r context_flags=''
  fi

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  local -r remote_size="$(
    sx::k8s::cli ${context_flags} exec --namespace "${ns}" "${name}" --container "${container}" -- \
      sh -c "wc -c < '${remote_file}'" 2>/dev/null | tr -d '[:space:]' \
      || true
  )"

  # "kubectl cp" resumes on its own when it reads a normal path, but the dump of the JDK container
  # is read through "/proc/<pid>/root", and there it ends with "error reading from error stream"
  # and writes a corrupt file without ever retrying. A plain "cat" is worse, it truncates and
  # still exits 0. So compress on the pod side, which also cuts a real dump to a third of the
  # bytes, and check the size on both ends.
  local compressed='false'
  # shellcheck disable=SC2086  # quote this to prevent word splitting
  if sx::os::is_command_available 'gzip' \
    && sx::k8s::cli ${context_flags} exec --namespace "${ns}" "${name}" --container "${container}" -- \
      sh -c 'command -v gzip' &>/dev/null; then

    compressed='true'
  fi
  readonly compressed

  if [ -z "${remote_size}" ]; then
    sx::k8s_command::jvm::copy_dump::read_from "${ns}" "${name}" "${container}" "${remote_file}" "${context}" "${compressed}" 0 >"${local_file}"

    return
  fi

  : >"${local_file}"

  local local_size='0'
  local previous_size='0'
  local stalled='0'
  local passes='0'

  # Whatever "gzip -d" writes before it hits the end of a cut stream is a correct prefix of the
  # file, and the dump does not change anymore, so each pass resumes at the local size instead of
  # starting over. A reset in the last percent of a 600MB dump then costs one short extra pass.
  while [ "${local_size}" -lt "${remote_size}" ]; do
    if [ "${passes}" -ge 20 ]; then
      sx::log::err "Gave up copying \"${remote_file}\" from pod \"${name}/${container}\" after ${passes} passes: ${local_size} bytes out of ${remote_size}."

      return 1
    fi

    passes=$((passes + 1))

    sx::k8s_command::jvm::copy_dump::read_from "${ns}" "${name}" "${container}" "${remote_file}" "${context}" "${compressed}" "${local_size}" >>"${local_file}"

    previous_size="${local_size}"
    local_size="$(wc -c <"${local_file}" | tr -d '[:space:]')"

    if [ "${local_size}" -le "${previous_size}" ]; then
      stalled=$((stalled + 1))

      if [ "${stalled}" -ge 3 ]; then
        sx::log::err "Incomplete copy of \"${remote_file}\" from pod \"${name}/${container}\": stopped at ${local_size} bytes out of ${remote_size}."

        return 1
      fi
    else
      stalled='0'

      if [ "${local_size}" -lt "${remote_size}" ]; then
        sx::log::info "Transfer interrupted at ${local_size} of ${remote_size} bytes, resuming..."
      fi
    fi
  done
}

function sx::k8s_command::jvm::copy_dump::read_from() {
  local -r ns="${1}"
  local -r name="${2}"
  local -r container="${3}"
  local -r remote_file="${4}"
  local -r context="${5:-}"
  local -r compressed="${6:-false}"
  local -r offset="${7:-0}"

  if [ -n "${context}" ]; then
    local -r context_flags="--context ${context}"
  else
    local -r context_flags=''
  fi

  # "tail -c +N" seeks, so resuming does not re-read what was already transferred
  local -r remote_command="tail -c +$((offset + 1)) '${remote_file}'"

  if ${compressed}; then
    # shellcheck disable=SC2086  # quote this to prevent word splitting
    sx::k8s::cli ${context_flags} exec --namespace "${ns}" "${name}" --container "${container}" -- \
      sh -c "${remote_command} | gzip -c -1" 2>/dev/null | gzip -dc 2>/dev/null || true
  else
    # shellcheck disable=SC2086  # quote this to prevent word splitting
    sx::k8s::cli ${context_flags} exec --namespace "${ns}" "${name}" --container "${container}" -- \
      sh -c "${remote_command}" 2>/dev/null || true
  fi
}

function sx::k8s_command::jvm::heapdump() {
  local -r ns="${1}"
  local -r name="${2}"
  local -r container="${3}"
  local -r pid="${4}"
  local -r timestamp="${5}"
  local -r output_dir="${6:-}"
  local -r context="${7:-}"
  local -r jdk_container="${8:-}"

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

  if [ -n "${jdk_container}" ]; then
    # The dump is always written by the JVM itself, so "${remote_file}" is a path in the target
    # container. The JDK container reads the very same file through the root of the JVM process.
    local -r source_container="${jdk_container}"
    local -r source_file="/proc/${pid}/root${remote_file}"

    if sx::k8s_command::jvm::jdk_exec "${ns}" "${name}" "${jdk_container}" "${pid}" "${context}" \
      jcmd "${pid}" 'GC.heap_dump' "${remote_file}" &>/dev/null; then

      sx::log::info "Heap dump generated in \"${remote_file}\" using \"jcmd\" from the JDK container."
    elif sx::k8s_command::jvm::jdk_exec "${ns}" "${name}" "${jdk_container}" "${pid}" "${context}" \
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
      sx::log::fatal "Failed to generate heap dump in pod \"${name}/${container}\": neither \"jcmd\" nor \"jmap\" is available (common on JRE-only/distroless images). Re-run with \"--jdk\" to run the JDK tooling from an ephemeral container."
    fi
  fi

  local copied='true'
  sx::k8s_command::jvm::copy_dump "${ns}" "${name}" "${source_container}" "${source_file}" "${local_file}" "${context}" || copied='false'

  # Always drop the dump from the pod, a failed copy leaves hundreds of megabytes behind otherwise
  # shellcheck disable=SC2086  # quote this to prevent word splitting
  sx::k8s::cli ${context_flags} exec --namespace "${ns}" "${name}" --container "${source_container}" -- rm -f "${source_file}" &>/dev/null || true

  if ! ${copied}; then
    sx::log::fatal "Failed to copy the heap dump out of pod \"${name}/${source_container}\"."
  fi

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
  local -r jdk_container="${8:-}"

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

  # The JDK tooling answers on the stdout of the attaching process, which is the JDK container
  # here, so the dump streams straight into the local file. Nothing is written in the pod.
  if [ -n "${jdk_container}" ]; then
    if sx::k8s_command::jvm::jdk_exec "${ns}" "${name}" "${jdk_container}" "${pid}" "${context}" \
      jcmd "${pid}" 'Thread.print' 2>/dev/null >"${local_file}"; then

      sx::log::info 'Thread dump generated using "jcmd" from the JDK container.'
    elif sx::k8s_command::jvm::jdk_exec "${ns}" "${name}" "${jdk_container}" "${pid}" "${context}" \
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

    if sx::k8s_command::jvm::capture_dump_from_logs "${ns}" "${name}" "${container}" "${local_file}" "${context}" 'Full thread dump' '^JNI global refs:'; then
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

function sx::k8s_command::jvm::capture_dump_from_logs() {
  local -r ns="${1}"
  local -r name="${2}"
  local -r container="${3}"
  local -r local_file="${4}"
  local -r context="${5:-}"
  local -r start_re="${6}"
  local -r end_re="${7}"

  if [ -n "${context}" ]; then
    local -r context_flags="--context ${context}"
  else
    local -r context_flags=''
  fi

  # Signal-triggered dumps (kill -3 / SIGUSR1) print to the JVM's stdout/stderr, i.e.
  # the pod logs, not a file. awk keeps the LAST complete "start_re ... end_re" block;
  # our just-triggered dump is the newest, so it is the block captured once it flushes.
  # The buffer resets only when not already capturing, so this works whether the start
  # marker appears once per dump (thread dump) or many times (fiber dump).
  # shellcheck disable=SC2016  # awk uses its own field vars ($0), not shell expansion
  local -r extractor='
    $0 ~ start_re { if (!cap) { cap = 1; buf = "" } buf = buf $0 ORS; next }
    cap { buf = buf $0 ORS }
    cap && $0 ~ end_re { result = buf; cap = 0 }
    END { if (cap) result = buf; printf "%s", result }
  '

  local dump=''
  for _ in 1 2 3 4 5 6; do
    sleep 1 # let the JVM flush the dump to the logs before reading

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    dump="$(
      sx::k8s::cli ${context_flags} logs "${name}" \
        --namespace "${ns}" \
        --container "${container}" \
        --since '30s' 2>/dev/null \
        | awk -v start_re="${start_re}" -v end_re="${end_re}" "${extractor}" \
        || true
    )"

    printf '%s' "${dump}" | grep -qE "${end_re}" && break
  done

  if [ -z "${dump}" ]; then
    return 1
  fi

  printf '%s\n' "${dump}" >"${local_file}"
}

function sx::k8s_command::jvm::fiberdump() {
  local -r ns="${1}"
  local -r name="${2}"
  local -r container="${3}"
  local -r pid="${4}"
  local -r timestamp="${5}"
  local -r output_dir="${6:-}"
  local -r context="${7:-}"
  local -r force="${8:-false}"

  if [ -n "${context}" ]; then
    local -r context_flags="--context ${context}"
  else
    local -r context_flags=''
  fi

  local -r filename="fiberdump-${name}-${timestamp}.txt"

  if [ -n "${output_dir}" ]; then
    local -r local_file="${output_dir}/${filename}"
  else
    local -r local_file="./${filename}"
  fi

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

  if sx::k8s_command::jvm::capture_dump_from_logs "${ns}" "${name}" "${container}" "${local_file}" "${context}" '^cats.effect.IOFiber@' '^Global: enqueued'; then
    sx::log::info "Fiber dump triggered using SIGUSR1, captured from the pod logs and saved to: ${local_file}."
  else
    sx::log::info 'Fiber dump triggered using SIGUSR1. Output is in the JVM stderr/logs; it could not be auto-captured to a file (is this a Cats Effect 3 app with active fibers?).'
  fi
}
