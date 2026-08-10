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
  local -r glibc_alloc_info="${10:-false}"

  sx::k8s::check_requirements

  # Both checked before anything reaches out to the cluster, so a wrong invocation fails right away
  # instead of after the pod picker.
  if ${glibc_alloc_info} && [ -z "${image}" ]; then
    sx::log::fatal '"--glibc-alloc-info" runs "gdb" from an ephemeral container. Re-run with an image shipping it, e.g. "--image ghcr.io/hpedrorodrigues/gdb".'
  fi

  # "--level" drives the Native Memory Tracking report, which "--glibc-alloc-info" replaces entirely.
  if ! ${glibc_alloc_info}; then
    sx::jvm_command::nativememory::validate_level "${level}"
  fi

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

  # The preflight of "resolve_pid" checks the attach handshake of the JVM, which only the Native
  # Memory Tracking report needs. "--glibc-alloc-info" reads "/proc" and drives "gdb" instead, so the
  # helper container is left out of the resolution: it would only demand tooling ("grep", "mount",
  # "setpriv") that an image shipping "gdb" has no reason to carry.
  local pid
  if ${glibc_alloc_info}; then
    pid="$(sx::jvm::resolve_pid "${ns}" "${name}" "${container_name}" "${context}")"
  else
    pid="$(sx::jvm::resolve_pid "${ns}" "${name}" "${container_name}" "${context}" "${jdk_container}")"
  fi
  readonly pid

  local -r timestamp="$(date '+%Y%m%d-%H%M%S')"

  if ${glibc_alloc_info}; then
    sx::jvm_command::nativememory::glibc_alloc_info "${ns}" "${name}" "${container_name}" "${pid}" "${context}" "${jdk_container}"
  else
    sx::jvm_command::nativememory "${ns}" "${name}" "${container_name}" "${pid}" "${timestamp}" "${context}" "${jdk_container}" "${level}"
  fi
}

# Reports what the operating system holds, which is what Native Memory Tracking cannot show:
# NMT only accounts for allocations made through the own "os::malloc" wrappers of the JVM, so
# everything a JNI library allocates, and everything glibc keeps after a "free", is invisible to
# it. glibc caps its malloc arenas at "8 x cores" (NARENAS_FROM_NCORES in malloc/malloc.c) reading
# the cores of the *node*, never the CPU limit of the container, and it destroys no arena and
# returns almost nothing to the kernel. So the resident memory of a JVM converges on the sum of the
# high-water mark of every arena instead of the peak it actually needed.
function sx::jvm_command::nativememory::glibc_alloc_info() {
  local -r ns="${1}"
  local -r name="${2}"
  local -r container="${3}"
  local -r pid="${4}"
  local -r context="${5:-}"
  local -r gdb_container="${6}"

  sx::log::info "Reading the native memory usage of pod \"${name}/${container}\" (PID: ${pid})..."

  local report
  report="$(sx::jvm_command::nativememory::glibc_alloc_info::collect "${ns}" "${name}" "${container}" "${pid}" "${context}")"
  readonly report

  if [ -z "${report}" ]; then
    sx::log::fatal "Failed to read \"/proc/${pid}\" in pod \"${name}/${container}\"."
  fi

  local rows
  rows="$(printf '%s\n' "${report}" | sx::jvm_command::nativememory::glibc_alloc_info::render)"

  # Everything from here on is glibc: no other implementation keeps malloc arenas or exports
  # "malloc_info". The check names the one implementation that works instead of listing the ones
  # that do not, so an undetected libc stops here too, where guessing glibc would only show up as
  # "gdb" failing to find a symbol.
  local -r implementation="$(printf '%s\n' "${rows}" | awk -F '\t' '$1 == "libc" && $2 == "implementation" { print $3 }')"

  if [ "${implementation}" != 'glibc' ]; then
    sx::log::fatal "The C library of pod \"${name}/${container}\" reads as \"${implementation}\", and \"--glibc-alloc-info\" supports glibc only: no other implementation keeps malloc arenas or exports \"malloc_info\"."
  fi

  # Logged from here, not from the function: its stdout is captured as rows of the table, and a
  # line holding no separator would stretch the first column to its own width.
  sx::log::info "Attaching \"gdb\" to PID ${pid} to call \"malloc_info\". Every thread of the JVM stops while it runs."

  rows+=$'\n'"$(sx::jvm_command::nativememory::glibc_alloc_info::arenas "${ns}" "${name}" "${container}" "${pid}" "${context}" "${gdb_container}")"

  # Tab separated, because the descriptions hold commas.
  printf 'SECTION\tMETRIC\tVALUE\tDESCRIPTION\n%s\n' "${rows}" | column -t -s $'\t'
}

# Everything is read in a single exec and parsed on this side: a JRE-only image ships almost no
# tooling, and the "awk" of busybox has no "strtonum" to turn the addresses of smaps into numbers.
function sx::jvm_command::nativememory::glibc_alloc_info::collect() {
  local -r ns="${1}"
  local -r name="${2}"
  local -r container="${3}"
  local -r pid="${4}"
  local -r context="${5:-}"

  local -r context_flags="$(sx::jvm::context_flags "${context}")"

  # shellcheck disable=SC2016  # expressions don't expand in single quotes
  local -r payload='
    pid="${1}"

    echo "===status==="
    cat "/proc/${pid}/status" 2>/dev/null

    echo "===tasks==="
    ls "/proc/${pid}/task" 2>/dev/null

    echo "===env==="
    tr "\0" "\n" <"/proc/${pid}/environ" 2>/dev/null | grep "^MALLOC_" || true

    echo "===nproc==="
    nproc 2>/dev/null || grep -c "^processor" /proc/cpuinfo 2>/dev/null || true

    echo "===libc==="
    # "ldd" names the implementation and the version on both glibc ("Debian GLIBC 2.36") and musl
    # ("musl libc"). Running the library itself prints the same banner and covers the images that
    # ship no "ldd".
    ldd --version 2>&1 | head -1 || true
    libc="$(sed -n "s#.* \(/[^ ]*/libc[.-][^ ]*\)\$#\1#p" "/proc/${pid}/maps" 2>/dev/null | head -1)"
    if [ -n "${libc}" ]; then
      echo "path ${libc}"
      "${libc}" 2>/dev/null | head -1 || true
    fi

    echo "===uptime==="
    # Arenas only grow to their high-water mark over time, so the age of the process says whether
    # the numbers below mean anything yet. Field 22 of "stat" is the start time in clock ticks, and
    # the name of the process is stripped first because it may itself hold spaces or brackets.
    cut -d " " -f 1 /proc/uptime 2>/dev/null || echo -
    sed "s/^.*) //" "/proc/${pid}/stat" 2>/dev/null | cut -d " " -f 20 || echo -
    getconf CLK_TCK 2>/dev/null || echo 100

    echo "===cgroup==="
    cat /sys/fs/cgroup/memory.current 2>/dev/null || cat /sys/fs/cgroup/memory/memory.usage_in_bytes 2>/dev/null || echo -
    cat /sys/fs/cgroup/memory.max 2>/dev/null || cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null || echo -
    cat /sys/fs/cgroup/memory.peak 2>/dev/null || cat /sys/fs/cgroup/memory/memory.max_usage_in_bytes 2>/dev/null || echo -

    echo "===cgroupevents==="
    # "max" counts the times the limit was reached and "oom_kill" the times the kernel killed
    # something in this cgroup: the difference between a container under pressure and one that has
    # already been killed. Neither is visible from the process itself.
    cat /sys/fs/cgroup/memory.events 2>/dev/null || true

    echo "===smaps==="
    cat "/proc/${pid}/smaps" 2>/dev/null
  '

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  sx::k8s::cli ${context_flags} exec --namespace "${ns}" "${name}" --container "${container}" -- \
    sh -c "${payload}" 'sx-jvm' "${pid}" 2>/dev/null || true
}

function sx::jvm_command::nativememory::glibc_alloc_info::render() {
  # A non-main arena is an mmap of exactly HEAP_MAX_SIZE, which is "2 x DEFAULT_MMAP_THRESHOLD_MAX"
  # = 64 MiB on 64-bit, and has to be a power of two so glibc can find the arena of any address by
  # masking it (malloc/arena.c). Grouping the anonymous mappings by that alignment and keeping the
  # groups that add up to exactly 64 MiB counts them, whether or not glibc has split a group into a
  # committed and an uncommitted part.
  awk '
    function hex2dec(value,   i, char, digit, result) {
      result = 0
      value = tolower(value)
      for (i = 1; i <= length(value); i++) {
        char = substr(value, i, 1)
        digit = index("0123456789abcdef", char) - 1
        if (digit < 0) { return -1 }
        result = result * 16 + digit
      }
      return result
    }
    function mib(bytes) { return sprintf("%.0f MiB", bytes / 1048576) }
    function duration(seconds,   days, hours, minutes) {
      days = int(seconds / 86400)
      hours = int((seconds % 86400) / 3600)
      minutes = int((seconds % 3600) / 60)
      if (days > 0) { return sprintf("%dd%dh", days, hours) }
      if (hours > 0) { return sprintf("%dh%dm", hours, minutes) }
      return sprintf("%dm", minutes)
    }
    BEGIN { arena = 67108864; bucket = -1; highest_tid = 0 }
    /^===/ { section = substr($0, 4, length($0) - 6); next }
    section == "libc" { libc = libc " " $0 }
    section == "uptime" { uptime[++uptimes] = $1 }
    section == "cgroupevents" && /^(max|oom_kill) / { event[$1] = $2 }
    section == "status" && /^VmRSS:/ { rss = $2 * 1024 }
    section == "status" && /^VmHWM:/ { peak = $2 * 1024 }
    section == "status" && /^VmSwap:/ { swap = $2 * 1024 }
    section == "status" && /^Threads:/ { threads = $2 }
    section == "tasks" && /^[0-9]+$/ { if ($1 > highest_tid) { highest_tid = $1 } }
    section == "env" && /^MALLOC_ARENA_MAX=/ { split($0, kv, "="); arena_max = kv[2] }
    section == "nproc" && /^[0-9]+$/ { cores = $1 }
    section == "cgroup" { cgroup[++cgroups] = $1 }
    section == "smaps" && /^[0-9a-f]+-[0-9a-f]+ / {
      split($1, range, "-")
      if (NF == 5) {
        start = hex2dec(range[1])
        end = hex2dec(range[2])
        bucket = int(start / arena)
        size[bucket] += end - start
        anonymous = 1

        # A reservation is one mmap that the kernel reports as several lines whenever parts of it
        # differ in permissions, which is exactly what an uncommitted Java heap looks like. Joining
        # the lines that continue the previous one measures the reservation instead of its pieces.
        if (start == reservation_end) {
          reservation += end - start
        } else {
          reservation = end - start
          reservation_rss = 0
        }
        reservation_end = end
        if (reservation > largest) { largest = reservation; largest_is_current = 1 }
        else { largest_is_current = 0 }
      } else {
        bucket = -1
        anonymous = 0
        reservation_end = -1
        largest_is_current = 0
      }
      next
    }
    section == "smaps" && /^Rss:/ {
      if (bucket >= 0) { resident[bucket] += $2 * 1024 }
      if (anonymous) {
        anon_rss += $2 * 1024
        reservation_rss += $2 * 1024
        if (largest_is_current) { largest_rss = reservation_rss }
      } else {
        file_rss += $2 * 1024
      }
    }
    END {
      for (key in size) {
        if (size[key] == arena) { arenas++; arena_rss += resident[key] }
      }

      if (libc ~ /musl/) { implementation = "musl" }
      else if (libc ~ /GLIBC|GNU libc/) { implementation = "glibc" }
      else { implementation = "unknown" }

      if (match(libc, /[0-9]+\.[0-9]+(\.[0-9]+)?/)) {
        version = substr(libc, RSTART, RLENGTH)
      } else {
        version = "n/a"
      }

      if (uptime[1] ~ /^[0-9.]+$/ && uptime[2] ~ /^[0-9]+$/ && uptime[3] > 0) {
        age = duration(uptime[1] - (uptime[2] / uptime[3]))
      } else {
        age = "n/a"
      }

      printf "process\tuptime\t%s\tAge of the process, arenas only fill over days\n", age
      printf "process\trss\t%s\tResident memory of the process\n", mib(rss)
      printf "process\trss_peak\t%s\tHighest resident memory since it started\n", mib(peak)
      printf "process\tswap\t%s\tResident memory pushed out to swap\n", mib(swap)
      printf "process\tthreads_live\t%d\tThreads alive right now\n", threads
      printf "process\thighest_tid\t%d\tThread ids handed out so far, shows churn\n", highest_tid
      printf "cgroup\tusage\t%s\tMemory the cgroup accounts for right now\n", (cgroup[1] ~ /^[0-9]+$/ ? mib(cgroup[1]) : "n/a")
      printf "cgroup\tpeak\t%s\tHighest the cgroup ever accounted for\n", (cgroup[3] ~ /^[0-9]+$/ ? mib(cgroup[3]) : "n/a")
      printf "cgroup\tlimit\t%s\tMemory limit of the container\n", (cgroup[2] ~ /^[0-9]+$/ ? mib(cgroup[2]) : "none")
      printf "cgroup\tlimit_hits\t%s\tTimes the limit was reached\n", (("max" in event) ? event["max"] : "n/a")
      printf "cgroup\toom_kills\t%s\tTimes the kernel killed a process in here\n", (("oom_kill" in event) ? event["oom_kill"] : "n/a")
      printf "libc\timplementation\t%s\tArenas only exist on glibc\n", implementation
      printf "libc\tversion\t%s\tVersion of the C library of the container\n", version
      printf "memory\tanonymous\t%s\tResident memory backed by no file\n", mib(anon_rss)
      printf "memory\tfile_backed\t%s\tResident memory of mapped files\n", mib(file_rss)
      # The biggest anonymous reservation of a JVM is its heap, mapped whole at startup and
      # committed into as it grows, so this is the allowance to compare against the cgroup limit.
      printf "memory\tlargest_reservation\t%s\tBiggest single mapping, usually the Java heap\n", mib(largest)
      printf "memory\tlargest_reservation_resident\t%s\tHow much of that mapping is resident\n", mib(largest_rss)
      printf "arenas\tblocks\t%d\t64 MiB blocks, the arenas plus a few JVM regions\n", arenas
      printf "arenas\tresident\t%s\tResident memory inside those blocks\n", mib(arena_rss)
      # Whatever is anonymous and not an arena: the Java heap, metaspace, the code cache, the
      # thread stacks and the main arena.
      printf "arenas\tother_anonymous\t%s\tAnonymous memory outside them: heap, stacks, JIT\n", mib(anon_rss - arena_rss)
      printf "arenas\tmalloc_arena_max\t%s\tCap in effect, empty when glibc chooses it\n", (arena_max == "" ? "unset" : arena_max)
      printf "arenas\tglibc_default\t%s\tCap glibc picks on its own: 8 x cores of the node\n", (cores == "" ? "n/a" : cores * 8)
    }
  '
}

# "malloc_info" is only reachable as a C call, so "gdb" has to attach to the JVM to make it. That
# stops every thread of the process for the duration, which is under a second in practice, but a
# pod whose liveness probe has little slack can still be restarted by the kubelet because of it.
function sx::jvm_command::nativememory::glibc_alloc_info::arenas() {
  local -r ns="${1}"
  local -r name="${2}"
  local -r container="${3}"
  local -r pid="${4}"
  local -r context="${5:-}"
  local -r gdb_container="${6}"

  local -r context_flags="$(sx::jvm::context_flags "${context}")"
  local -r remote_file="/tmp/malloc_info-${pid}.xml"

  # The sysroot has to be set before the attach: with "gdb -p <pid>" the attach happens before the
  # "-ex" flags run, no symbol of libc resolves, and every call fails with "No symbol table is
  # loaded". The file is written by the JVM itself, so it lands in the mount namespace of the
  # target container, not in the one of the container running "gdb".
  # Checked apart from the attach below, so a missing tool and a refused attach stop looking like
  # the same failure.
  # shellcheck disable=SC2086  # quote this to prevent word splitting
  if ! sx::k8s::cli ${context_flags} exec --namespace "${ns}" "${name}" --container "${gdb_container}" -- \
    sh -c 'command -v gdb' &>/dev/null; then

    sx::log::fatal "The image of the ephemeral container \"${gdb_container}\" ships no \"gdb\". Re-run with one that does, e.g. \"--image ghcr.io/hpedrorodrigues/gdb\"."
  fi

  local output=''

  # shellcheck disable=SC2016,SC2086  # "$f" is a convenience variable of gdb, not of the shell; quote this to prevent word splitting
  if ! output="$(
    sx::k8s::cli ${context_flags} exec --namespace "${ns}" "${name}" --container "${gdb_container}" -- \
      gdb -batch \
      -ex 'set confirm off' \
      -ex "set sysroot /proc/${pid}/root" \
      -ex "attach ${pid}" \
      -ex "set \$f = (void *) fopen(\"${remote_file}\", \"w\")" \
      -ex 'call (int) malloc_info(0, $f)' \
      -ex 'call (int) fclose($f)' \
      -ex 'detach' 2>&1
  )"; then

    sx::log::fatal "\"gdb\" failed to run \"malloc_info\" against PID ${pid} of pod \"${name}/${container}\":\n\n${output}"
  fi

  local xml
  # shellcheck disable=SC2086  # quote this to prevent word splitting
  xml="$(
    sx::k8s::cli ${context_flags} exec --namespace "${ns}" "${name}" --container "${container}" -- \
      cat "${remote_file}" 2>/dev/null || true
  )"
  readonly xml

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  sx::k8s::cli ${context_flags} exec --namespace "${ns}" "${name}" --container "${container}" -- \
    rm -f "${remote_file}" &>/dev/null || true

  if [ -z "${xml}" ]; then
    sx::log::fatal "\"malloc_info\" wrote no report in pod \"${name}/${container}\"."
  fi

  # Only the totals of the trailing <malloc> element are reported: the per-heap elements repeat for
  # every arena and say little on their own.
  printf '%s\n' "${xml}" | awk '
    function mib(bytes) { return sprintf("%.0f MiB", bytes / 1048576) }
    function value(line,   parts) { split(line, parts, "size=\""); split(parts[2], parts, "\""); return parts[1] }
    # Every <heap> element repeats the same fields the trailing totals use, so the state of a
    # single arena is kept while inside one and folded into the distribution when it closes.
    /<heap nr=/ { arenas++; inside = 1; heap_free = 0; heap_held = 0; next }
    inside && /<total type="rest"/ { heap_free += value($0); next }
    inside && /<total type="fast"/ { heap_free += value($0); next }
    inside && /<system type="current"/ { heap_held = value($0); next }
    /<\/heap>/ {
      inside = 0
      if (heap_held > 0) {
        share = heap_free * 100 / heap_held
        shares[++samples] = share
        if (share >= 90) { stranded++ }
        if (share > widest) { widest = share }
      }
      next
    }
    /<total type="rest"/ { free = value($0) }
    /<total type="fast"/ { fast = value($0) }
    /<system type="current"/ { held = value($0) }
    /<system type="max"/ { peak = value($0) }
    END {
      printf "malloc_info\tarenas\t%d\tArenas glibc reports itself\n", arenas
      printf "malloc_info\theld\t%s\tMemory the arenas hold from the kernel\n", mib(held)
      printf "malloc_info\tpeak_held\t%s\tMost the arenas ever held\n", mib(peak)
      printf "malloc_info\tfree\t%s\tPart of held that was freed but never returned\n", mib(free + fast)
      printf "malloc_info\tretained\t%.1f%%\tFree as a share of held\n", (held > 0 ? (free + fast) * 100 / held : 0)

      # An arena that is almost entirely free is memory no other thread can reach: it belongs to
      # that arena and glibc will not hand it back. Counting them shows the stranding a single
      # total hides.
      for (i = 1; i <= samples; i++) {
        for (j = i + 1; j <= samples; j++) {
          if (shares[j] < shares[i]) { swap = shares[i]; shares[i] = shares[j]; shares[j] = swap }
        }
      }
      printf "malloc_info\tarenas_over_90pct_free\t%d\tArenas at least 90%% free, that memory is stranded there\n", stranded + 0
      printf "malloc_info\tarena_free_median\t%.1f%%\tHalf of the arenas are at least this free\n", (samples > 0 ? shares[int((samples + 1) / 2)] : 0)
      printf "malloc_info\tarena_free_max\t%.1f%%\tHow free the emptiest arena is\n", widest + 0
    }
  '
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
