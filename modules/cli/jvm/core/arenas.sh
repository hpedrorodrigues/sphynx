#!/usr/bin/env bash

function sx::jvm::arenas() {
  local -r query="${1:-}"
  local -r selector="${2:-}"
  local -r namespace="${3:-}"
  local -r pod="${4:-}"
  local -r container="${5:-}"
  local -r all_namespaces="${6:-false}"
  local -r context="${7:-}"
  local -r image="${8:-}"
  local -r trim="${9:-false}"

  sx::k8s::check_requirements

  # Checked before anything reaches out to the cluster, so a wrong invocation fails right away
  # instead of after the pod picker.
  if [ -z "${image}" ]; then
    sx::log::fatal '"arenas" runs "gdb" from an ephemeral container. Re-run with an image shipping it, e.g. "--image ghcr.io/hpedrorodrigues/gdb".'
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

  local -r gdb_container="$(sx::jvm::jdk_container_name)"

  # shellcheck disable=SC2064  # expand the arguments now so the trap stops the right container
  trap "sx::jvm::stop_jdk_container '${ns}' '${name}' '${gdb_container}' '${context}'" EXIT

  sx::jvm::start_jdk_container "${ns}" "${name}" "${container_name}" "${gdb_container}" "${image}" "${context}"

  # The helper container is left out of the resolution on purpose: the preflight of "resolve_pid"
  # checks the attach handshake of the JVM, which only "jcmd" needs, and would demand tooling
  # ("grep", "mount", "setpriv") that an image shipping "gdb" has no reason to carry.
  local pid
  pid="$(sx::jvm::resolve_pid "${ns}" "${name}" "${container_name}" "${context}")"
  readonly pid

  sx::jvm_command::arenas "${ns}" "${name}" "${container_name}" "${pid}" "${context}" "${gdb_container}" "${trim}"
}

function sx::jvm_command::arenas() {
  local -r ns="${1}"
  local -r name="${2}"
  local -r container="${3}"
  local -r pid="${4}"
  local -r context="${5:-}"
  local -r gdb_container="${6}"
  local -r trim="${7:-false}"

  sx::log::info "Reading the native memory usage of pod \"${name}/${container}\" (PID: ${pid})..."

  local report
  report="$(sx::jvm_command::arenas::collect "${ns}" "${name}" "${container}" "${pid}" "${context}")"
  readonly report

  if [ -z "${report}" ]; then
    sx::log::fatal "Failed to read \"/proc/${pid}\" in pod \"${name}/${container}\"."
  fi

  local rows
  rows="$(printf '%s\n' "${report}" | sx::jvm_command::arenas::render)"

  # Everything from here on is glibc: no other implementation keeps malloc arenas or exports
  # "malloc_info". The check names the one implementation that works instead of listing the ones
  # that do not, so an undetected libc stops here too, where guessing glibc would only show up as
  # "gdb" failing to find a symbol.
  local -r implementation="$(printf '%s\n' "${rows}" | awk -F '\t' '$1 == "libc" && $2 == "implementation" { print $3 }')"

  if [ "${implementation}" != 'glibc' ]; then
    sx::log::fatal "The C library of pod \"${name}/${container}\" reads as \"${implementation}\", and \"arenas\" supports glibc only: no other implementation keeps malloc arenas or exports \"malloc_info\"."
  fi

  # Logged from here, not from the function: its stdout is captured as rows of the table, and a
  # line holding no separator would stretch the first column to its own width.
  if ${trim}; then
    sx::log::info "Attaching \"gdb\" to PID ${pid} to call \"malloc_info\", then \"malloc_trim\", then \"malloc_info\" again. Every thread of the JVM stops while these run, and interrupting the command before it detaches can crash the JVM."
  else
    sx::log::info "Attaching \"gdb\" to PID ${pid} to call \"malloc_info\". Every thread of the JVM stops while it runs."
  fi

  local released
  released="$(
    sx::jvm_command::arenas::attach "${ns}" "${name}" "${container}" "${pid}" "${context}" "${gdb_container}" "${trim}"
  )"
  readonly released

  rows+=$'\n'"$(sx::jvm_command::arenas::malloc_info "${ns}" "${name}" "${container}" "${pid}" "${context}" 'before')"

  # Read here and not where the second table needs it: a report does not change once it is written,
  # so reading both in the same breath costs nothing, and a failure in between would otherwise leave
  # a file behind in a container this command cannot come back to.
  local after_malloc_info=''
  if ${trim}; then
    after_malloc_info="$(
      sx::jvm_command::arenas::malloc_info "${ns}" "${name}" "${container}" "${pid}" "${context}" 'after'
    )"
  fi
  readonly after_malloc_info

  # Kept before the library rows are appended: those are a list of suspects rather than metrics, and
  # the second table pairs rows by their section and metric.
  local -r before_rows="${rows}"

  rows+=$'\n'"$(printf '%s\n' "${report}" | sx::jvm_command::arenas::libraries)"

  # "BEFORE" whenever a second table follows to be compared against it. The values were read before
  # the trim even though the table is printed after it ran: one attach does both calls, so the report
  # cannot be printed until the trim it precedes is already done.
  local value_header='VALUE'
  if ${trim}; then
    value_header='BEFORE'
  fi
  readonly value_header

  # Tab separated, because the descriptions hold commas.
  echo
  printf 'SECTION\tMETRIC\t%s\tDESCRIPTION\n%s\n' "${value_header}" "${rows}" | column -t -s $'\t'

  if ! ${trim}; then
    return 0
  fi

  # Read after the detach, over a round trip of its own, so the JVM has been allocating again for a
  # second or two and the second column carries that drift. Reading it from inside the attach would
  # remove the drift and lengthen the pause instead, which is the worse trade for a report whose
  # whole point is that the pause is short. The cgroup counters lag further still, because the kernel
  # charges them in per-CPU batches, so "cgroup usage" is expected to trail "process rss" rather than
  # match it. What the table shows is the size of the change, not its exact value: the other replica
  # of the same deployment is what tells a trim apart from ordinary growth.
  local after_report
  after_report="$(sx::jvm_command::arenas::collect "${ns}" "${name}" "${container}" "${pid}" "${context}")"
  readonly after_report

  if [ -z "${after_report}" ]; then
    sx::log::fatal "Failed to read \"/proc/${pid}\" in pod \"${name}/${container}\" after \"malloc_trim(0)\". The trim itself already ran, so re-running without \"--trim\" reports the state it left behind."
  fi

  local after_rows
  after_rows="$(printf '%s\n' "${after_report}" | sx::jvm_command::arenas::render)"
  after_rows+=$'\n'"${after_malloc_info}"
  readonly after_rows

  # Reported only when glibc found nothing at all to hand back, which is the case worth a sentence:
  # no free chunk of any arena covered a whole page, so the table below is expected to be flat. The
  # other answer says only that some page-aligned free space existed, not that it was resident, so a
  # "1" beside an unchanged resident set is ordinary and saying so would read as a contradiction.
  if [ "${released}" = '0' ]; then
    sx::log::info "\n\"malloc_trim(0)\" returned nothing to the kernel: no free chunk of any arena covered a whole page, so this JVM has nothing to gain from a trim."
  fi

  echo
  printf 'SECTION\tMETRIC\tBEFORE\tAFTER\tDESCRIPTION\n%s\n' \
    "$(sx::jvm_command::arenas::compare "${before_rows}" "${after_rows}")" | column -t -s $'\t'
}

# Everything is read in a single exec and parsed on this side: a JRE-only image ships almost no
# tooling, and the "awk" of busybox has no "strtonum" to turn the addresses of smaps into numbers.
function sx::jvm_command::arenas::collect() {
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

    echo "===jcmd==="
    # What the JVM itself committed, which is the only way to tell its memory apart from the rest
    # of the resident set. Absent from JRE-only images, where the report falls back to "n/a".
    command -v jcmd >/dev/null 2>&1 && jcmd "${pid}" GC.heap_info 2>/dev/null || true

    echo "===smaps==="
    cat "/proc/${pid}/smaps" 2>/dev/null
  '

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  sx::k8s::cli ${context_flags} exec --namespace "${ns}" "${name}" --container "${container}" -- \
    sh -c "${payload}" 'sx-jvm' "${pid}" 2>/dev/null || true
}

function sx::jvm_command::arenas::render() {
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
    # Reads the "<label> <n>K" that "jcmd" prints, in bytes.
    function kb_after(line, label) {
      if (match(line, label " [0-9]+K")) {
        return substr(line, RSTART + length(label) + 1, RLENGTH - length(label) - 2) * 1024
      }
      return 0
    }
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
    # "GC.heap_info" prints "total <n>K" for the committed heap and "committed <n>K" for the two
    # metaspace lines. Written for G1, the collector every workload here runs.
    section == "jcmd" && /heap  *total [0-9]+K/ { heap_committed = kb_after($0, "total") }
    section == "jcmd" && /^ *Metaspace/ { metaspace = kb_after($0, "committed") }
    section == "jcmd" && /^ *class space/ { class_space = kb_after($0, "committed") }
    section == "smaps" && /^[0-9a-f]+-[0-9a-f]+ / {
      split($1, range, "-")
      if (NF == 5) {
        start = hex2dec(range[1])
        end = hex2dec(range[2])
        bucket = int(start / arena)
        size[bucket] += end - start
        anonymous = 1

        # Kept for a second pass: whether a mapping belongs to an arena is only known once every
        # bucket has been summed, and joining arenas into a "reservation" would invent one, since
        # they sit next to each other in the address space.
        mappings++
        map_start[mappings] = start
        map_end[mappings] = end
        map_bucket[mappings] = bucket
        current = mappings
      } else {
        bucket = -1
        anonymous = 0
        current = 0
      }
      next
    }
    section == "smaps" && /^Rss:/ {
      if (bucket >= 0) { resident[bucket] += $2 * 1024 }
      if (anonymous) {
        anon_rss += $2 * 1024
        if (current > 0) { map_rss[current] += $2 * 1024 }
      } else {
        file_rss += $2 * 1024
      }
    }
    END {
      for (key in size) {
        if (size[key] == arena) { arenas++; arena_rss += resident[key]; is_arena[key] = 1 }
      }

      # Second pass for the biggest reservation. The kernel reports one mmap as several lines when
      # parts of it differ in permissions, which is what an uncommitted Java heap looks like, so the
      # lines that continue the previous one are joined. Arenas are left out: they are separate
      # mmaps that merely sit side by side, and joining them invents a reservation that never
      # existed.
      previous_end = -1
      for (i = 1; i <= mappings; i++) {
        if (is_arena[map_bucket[i]]) { previous_end = -1; continue }

        if (map_start[i] == previous_end) {
          run += map_end[i] - map_start[i]
          run_rss += map_rss[i]
        } else {
          run = map_end[i] - map_start[i]
          run_rss = map_rss[i]
        }
        previous_end = map_end[i]

        if (run > largest) { largest = run; largest_rss = run_rss }
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
      # Only the JVM knows what it committed, so without "jcmd" its share of the resident set
      # cannot be told apart from everything else and no "native" figure is possible.
      if (heap_committed > 0) {
        printf "jvm\tcommitted_heap\t%s\tHeap the JVM has committed, not what it may reserve\n", mib(heap_committed)
        printf "jvm\tmetaspace\t%s\tMetaspace the JVM has committed\n", mib(metaspace)
        printf "jvm\tclass_space\t%s\tCompressed class space the JVM has committed\n", mib(class_space)
      } else {
        printf "jvm\tcommitted_heap\tn/a\tNeeds \"jcmd\", which JRE-only images do not ship\n"
      }

      printf "memory\tanonymous\t%s\tResident memory backed by no file\n", mib(anon_rss)
      printf "memory\tfile_backed\t%s\tResident memory of mapped files\n", mib(file_rss)
      # The biggest anonymous reservation of a JVM is its heap, mapped whole at startup and
      # committed into as it grows, so this is the allowance to compare against the cgroup limit.
      printf "memory\tlargest_reservation\t%s\tBiggest single mapping, usually the Java heap\n", mib(largest)
      printf "memory\tlargest_reservation_resident\t%s\tHow much of that mapping is resident\n", mib(largest_rss)
      # The figure the whole report exists for: resident memory the JVM does not account for. The
      # code cache is not in "GC.heap_info", so it lands in here too.
      if (heap_committed > 0) {
        printf "memory\tnative\t%s\tRSS minus what the JVM committed, code cache included\n", mib(rss - heap_committed - metaspace - class_space)
      }
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

# Listed last, and from a pass of their own, because they close the report rather than measure it:
# every other section is a quantity, this one is a list of suspects for the memory those quantities
# leave unexplained.
function sx::jvm_command::arenas::libraries() {
  awk '
    function mib(bytes) { return sprintf("%.0f MiB", bytes / 1048576) }
    # A shared object belonging to neither the JDK nor the base system, so what is left is what the
    # application brought: the JNI libraries that allocate outside every JVM counter. A name list,
    # so it ages with the JDK, but nothing else tells the two apart.
    function is_foreign(name) {
      if (name !~ /\.so/) { return 0 }
      # The separator matters: it keeps "libnetty_transport_native_epoll" out of "libnet", while
      # still catching the "libawt_headless" and "libmanagement_ext" of the JDK.
      if (name ~ /^lib(jvm|java|nio|net|zip|jimage|management|awt|jsvml|jli|extnet|verify|instrument|attach)[._-]/) { return 0 }
      if (name ~ /^lib(c|m|dl|pthread|rt|resolv|util|crypt|nss)[._-]/) { return 0 }
      if (name ~ /^ld-(linux|musl)/) { return 0 }
      return 1
    }
    /^===/ { section = substr($0, 4, length($0) - 6); next }
    section == "smaps" && /^[0-9a-f]+-[0-9a-f]+ / {
      library = ""
      if (NF > 5) { parts = split($6, path, "/"); library = path[parts] }
      next
    }
    section == "smaps" && /^Rss:/ {
      if (library != "" && is_foreign(library)) { lib_rss[library] += $2 * 1024 }
    }
    END {
      for (name in lib_rss) {
        biggest = ""
        for (candidate in lib_rss) {
          if (lib_rss[candidate] > -1 && (biggest == "" || lib_rss[candidate] > lib_rss[biggest])) { biggest = candidate }
        }
        if (biggest == "" || ++listed > 6) { break }
        # A JNI library is unpacked to a temporary file with a random suffix, so the tail of the
        # name carries nothing and only the head identifies it.
        display = (length(biggest) > 34 ? substr(biggest, 1, 32) ".." : biggest)
        printf "libraries\t%s\t%s\tNative library of the application, allocates outside the JVM\n", display, mib(lib_rss[biggest])
        lib_rss[biggest] = -1
      }
    }
  '
}

# The two reports of one attach are told apart by the phase in their name. Built here because the
# attach writes the files and the parser reads them, and a path spelled out in both is a contract
# nothing checks.
function sx::jvm_command::arenas::dump_path() {
  local -r pid="${1}"
  local -r phase="${2}"

  echo "/tmp/malloc_info-${pid}-${phase}.xml"
}

# "malloc_info" is only reachable as a C call, so "gdb" has to attach to the JVM to make it, and with
# "trim" so is "malloc_trim". Both go in one batch: an attach stops every thread of the process, and
# a second one would double that and let the JVM allocate between the two reports, which is the one
# thing the comparison exists to measure. The pause is under a second in practice, but a pod whose
# liveness probe has little slack can still be restarted by the kubelet because of it.
#
# Every thread runs again during each call, though, because "gdb" makes an inferior call by letting
# the process go. So the JVM meets its own signals while a call is in flight, and HotSpot raises
# SIGSEGV as a matter of routine: implicit null checks and the safepoint polling page both work that
# way. Left at its default "gdb" stops everything on the first of them and runs the rest of the batch
# against a half-finished call, so the signals the JVM handles itself are passed straight through.
# "malloc_trim" is the call here that lasts long enough for one to be likely.
#
# The call is given a deadline as well, because an inferior call has none. If "gdb" picks a thread
# that was stopped inside "malloc" holding its own arena lock, "malloc_trim" waits on a lock it
# already owns and no other thread can break the tie. On a timeout "gdb" unwinds its dummy frame and
# detaches, which a "timeout" around the whole command could never do: killing "gdb" mid-call leaves
# the breakpoint of that frame in the process, and the JVM then takes a SIGTRAP it does not handle.
#
# Prints what "malloc_trim" returned, and nothing at all without "trim".
function sx::jvm_command::arenas::attach() {
  local -r ns="${1}"
  local -r name="${2}"
  local -r container="${3}"
  local -r pid="${4}"
  local -r context="${5:-}"
  local -r gdb_container="${6}"
  local -r trim="${7:-false}"

  local -r context_flags="$(sx::jvm::context_flags "${context}")"
  local -r before_file="$(sx::jvm_command::arenas::dump_path "${pid}" 'before')"
  local -r after_file="$(sx::jvm_command::arenas::dump_path "${pid}" 'after')"

  # Checked apart from the attach below, so a missing tool and a refused attach stop looking like
  # the same failure.
  # shellcheck disable=SC2086  # quote this to prevent word splitting
  if ! sx::k8s::cli ${context_flags} exec --namespace "${ns}" "${name}" --container "${gdb_container}" -- \
    sh -c 'command -v gdb' &>/dev/null; then

    sx::log::fatal "The image of the ephemeral container \"${gdb_container}\" ships no \"gdb\". Re-run with one that does, e.g. \"--image ghcr.io/hpedrorodrigues/gdb\"."
  fi

  # "malloc_info" writes its first line to the stream before it ever looks at it, so a "fopen" that
  # returns NULL is a null dereference inside the JVM and not a failure this command gets to report.
  # A read-only root filesystem and a "/tmp" the JVM may not write are both ordinary, so the write is
  # tried from the target container first, where the user is the one the JVM runs as. Checking it
  # inside the batch is not an option: "gdb" reads every "-ex" as a command of its own, and an "if"
  # spread over several of them runs both of its branches.
  # shellcheck disable=SC2086  # quote this to prevent word splitting
  if ! sx::k8s::cli ${context_flags} exec --namespace "${ns}" "${name}" --container "${container}" -- \
    sh -c "touch \"${before_file}\" && rm -f \"${before_file}\"" &>/dev/null; then

    sx::log::fatal "The JVM of pod \"${name}/${container}\" cannot write \"${before_file}\", and \"malloc_info\" writes to the stream before it checks it, so calling it would crash the JVM. Is the root filesystem read-only, or \"/tmp\" not writable by the user the container runs as?"
  fi

  # The sysroot has to be set before the attach: with "gdb -p <pid>" the attach happens before the
  # "-ex" flags run, no symbol of libc resolves, and every call fails with "No symbol table is
  # loaded". The files are written by the JVM itself, so they land in the mount namespace of the
  # target container, not in the one of the container running "gdb".
  # shellcheck disable=SC2016  # "$f" is a convenience variable of gdb, not of the shell
  local -a commands=(
    -batch
    -ex 'set confirm off'
    -ex 'set unwind-on-signal on'
    -ex 'set unwind-on-timeout on'
    -ex 'set direct-call-timeout 20'
    -ex "set sysroot /proc/${pid}/root"
    -ex "attach ${pid}"
    -ex 'handle SIGSEGV SIGBUS SIGFPE SIGILL SIGPIPE SIGQUIT SIG32 SIG33 SIG34 nostop noprint pass'
    -ex "set \$f = (void *) fopen(\"${before_file}\", \"w\")"
    -ex 'call (int) malloc_info(0, $f)'
    -ex 'call (int) fclose($f)'
  )

  if ${trim}; then
    # Behind a marker of ours rather than read out of the value history of "gdb", which numbers every
    # call: a batch carries on after a failed "-ex", so a libc exporting no "malloc_trim" would still
    # write a second report and leave that numbering shifted, and every metric would read as flat.
    # Flat is the answer this flag looks for, so it must not also be what failure looks like.
    # "malloc_trim" takes a "size_t", a typedef that does not resolve in a libc without debug
    # symbols, so the argument is cast to the type behind it. A wrong width there is silent: it
    # becomes padding glibc keeps, and the trim quietly does less.
    # shellcheck disable=SC2016  # "$g" is a convenience variable of gdb, not of the shell
    commands+=(
      -ex 'printf "sx-malloc-trim %d\n", (int) malloc_trim((unsigned long) 0)'
      -ex "set \$g = (void *) fopen(\"${after_file}\", \"w\")"
      -ex 'call (int) malloc_info(0, $g)'
      -ex 'call (int) fclose($g)'
    )
  fi

  commands+=(-ex 'detach')

  local output=''

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  if ! output="$(
    sx::k8s::cli ${context_flags} exec --namespace "${ns}" "${name}" --container "${gdb_container}" -- \
      gdb "${commands[@]}" 2>&1
  )"; then

    if ${trim}; then
      sx::log::fatal "\"gdb\" failed to run \"malloc_info\" and \"malloc_trim(0)\" against PID ${pid} of pod \"${name}/${container}\". Re-run without \"--trim\" for the report on its own:\n\n${output}"
    fi

    sx::log::fatal "\"gdb\" failed to run \"malloc_info\" against PID ${pid} of pod \"${name}/${container}\":\n\n${output}"
  fi

  if ! ${trim}; then
    return 0
  fi

  local -r released="$(printf '%s\n' "${output}" | awk '$1 == "sx-malloc-trim" { print $2 }')"

  if [ -z "${released}" ]; then
    sx::log::fatal "\"gdb\" attached to PID ${pid} of pod \"${name}/${container}\" but never ran \"malloc_trim(0)\": either the libc of that container exports no such symbol, or the call hit its deadline and was unwound. Re-run without \"--trim\" for the report on its own:\n\n${output}"
  fi

  echo "${released}"
}

# Turns one report of "malloc_info" into rows and takes it off the pod.
function sx::jvm_command::arenas::malloc_info() {
  local -r ns="${1}"
  local -r name="${2}"
  local -r container="${3}"
  local -r pid="${4}"
  local -r context="${5:-}"
  local -r phase="${6}"

  local -r context_flags="$(sx::jvm::context_flags "${context}")"
  local -r remote_file="$(sx::jvm_command::arenas::dump_path "${pid}" "${phase}")"

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
    # A trim cannot be undone, so failing after it has run is a failure to report and not one to
    # recover from. Said here, or the next run is another trim for nothing.
    if [ "${phase}" = 'after' ]; then
      sx::log::fatal "\"malloc_info\" wrote no second report in pod \"${name}/${container}\", so there is nothing to compare against. The trim itself already ran, so re-running without \"--trim\" reports the state it left behind."
    fi

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

# Pairs the rows of the two reports by their section and metric. Both values are printed as the report
# already formatted them and no difference is taken: subtracting them would mean either inheriting the
# whole-MiB rounding of the report or carrying a raw byte count through every "printf" of it, and the
# second reading has already spent more precision than either would buy back.
function sx::jvm_command::arenas::compare() {
  local -r before="${1}"
  local -r after="${2}"

  # The same marker "collect" uses to separate its own sections, for the same reason: the rows are
  # tab separated, so a line holding no tab cannot be one of them.
  printf '%s\n===after===\n%s\n' "${before}" "${after}" | awk -F '\t' '
    BEGIN {
      # Named rather than computed from what changed, because a computed table would be a diff of the
      # last two seconds: threads, thread ids and every library move on their own in a live JVM, and
      # sitting next to a trim they would read as its work. It would also drop the rows that carry
      # the answer, which are the ones that do not move.
      #
      # Those are here on purpose. "arenas blocks" is the clearest: "madvise(MADV_DONTNEED)" empties
      # pages without unmapping them or splitting the mapping, so the count of 64 MiB blocks is the
      # same afterwards, and the whole of a trim is that same mapping holding less. "held", "free"
      # and "retained" stay put because a trim leaves every chunk on its free list and never lowers
      # what the arena counts as its own, so a flat "held" beside a fallen "rss" is the finding and
      # not a disappointment. "rss_peak" and "cgroup peak" are high-water marks nothing can lower, so
      # one that moved means the JVM, not the trim.
      total = split("process/rss process/rss_peak process/swap" \
        " cgroup/usage cgroup/peak" \
        " memory/anonymous" \
        " arenas/blocks arenas/resident arenas/other_anonymous" \
        " malloc_info/held malloc_info/peak_held malloc_info/free malloc_info/retained" \
        " malloc_info/arenas_over_90pct_free malloc_info/arena_free_median" \
        " malloc_info/arena_free_max", wanted, " ")
    }
    NF == 1 { second = 1; next }
    {
      key = $1 "/" $2
      if (second) { after[key] = $3; next }
      before[key] = $3
      description[key] = $4
    }
    END {
      for (i = 1; i <= total; i++) {
        key = wanted[i]
        # Skipped rather than printed empty. A metric the report only prints under a condition would
        # otherwise land as a blank cell, and "column" folds neighbouring separators into one and
        # shifts every column after it along.
        if (!(key in before) || !(key in after)) { continue }

        split(key, parts, "/")
        printf "%s\t%s\t%s\t%s\t%s\n", parts[1], parts[2], before[key], after[key], description[key]
      }
    }
  '
}
