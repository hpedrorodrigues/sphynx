#!/usr/bin/env bash

# External images

export CONFLUENT_VERSION=${CONFLUENT_VERSION:-7.0.0}

## Kafka CLI (https://kafka.apache.org)
##
## e.g. kcli kafka-topics --bootstrap-server <host>:<port> --list
## e.g. kcli kafka-console-consumer --bootstrap-server <host>:<port> --topic <topic-name> --from-beginning
function kcli() {
  local -r tool_name="${FUNCNAME[0]:-${funcstack[1]}}"
  local -r random_port="$(shuf -i 2000-65000 -n 1)"

  local -r state="$(
    docker inspect --format '{{.State.Running}}' "${tool_name}" 2>/dev/null
  )"
  if [ "${state}" = 'true' ]; then
    echo >&2 "There's already an instance of \"${tool_name}\" running."
    return 1
  fi

  docker run \
    --rm \
    --name "${tool_name}" \
    --interactive \
    --publish "${random_port}:9092" \
    "confluentinc/cp-kafka:${CONFLUENT_VERSION}" "${@}"
}

# Sphynx images

export ALIEN_REPOSITORY="${ALIEN_REPOSITORY:-hpedrorodrigues/alien}"

## Prettier (https://prettier.io)
##
## e.g. prettier --check '*/**/*.{yml,yaml}'
function prettier() {
  local -r tool_name="${FUNCNAME[0]:-${funcstack[1]}}"
  local -r image="${ALIEN_REPOSITORY}:${tool_name}"

  if { [ -n "${ZSH_VERSION:-}" ] && whence -cp "${tool_name}" &>/dev/null; } \
    || { type -P "${tool_name}" &>/dev/null; }; then
    # shellcheck disable=SC2068  # Double quote array expansions
    # shellcheck disable=SC2086  # quote this to prevent word splitting
    command ${tool_name} ${@}
    return ${?}
  fi

  local -r state="$(
    docker inspect --format '{{.State.Running}}' "${tool_name}" 2>/dev/null
  )"
  if [ "${state}" = 'true' ]; then
    echo >&2 "There's already an instance of \"${tool_name}\" running."
    return 1
  fi

  docker run \
    --name "${tool_name}" \
    --rm \
    --interactive \
    --volume "${PRETTIER_DIR:-${PWD}}:/mnt" \
    "${image}" "${@}"
}

## Hadolint (https://github.com/hadolint/hadolint)
##
## e.g. hadolint < <path-to-Dockerfile>
function hadolint() {
  local -r tool_name="${FUNCNAME[0]:-${funcstack[1]}}"
  local -r image="${ALIEN_REPOSITORY}:${tool_name}"

  if { [ -n "${ZSH_VERSION:-}" ] && whence -cp "${tool_name}" &>/dev/null; } \
    || { type -P "${tool_name}" &>/dev/null; }; then
    # shellcheck disable=SC2068  # Double quote array expansions
    # shellcheck disable=SC2086  # quote this to prevent word splitting
    command ${tool_name} ${@}
    return ${?}
  fi

  local -r state="$(
    docker inspect --format '{{.State.Running}}' "${tool_name}" 2>/dev/null
  )"
  if [ "${state}" = 'true' ]; then
    echo >&2 "There's already an instance of \"${tool_name}\" running."
    return 1
  fi

  docker run \
    --name "${tool_name}" \
    --rm \
    --interactive \
    --volume "${HADOLINT_DIR:-${PWD}}:/mnt" \
    "${image}" "${@}"
}

## ShellCheck (https://github.com/koalaman/shellcheck)
##
## e.g. shellcheck <script-file>
function shellcheck() {
  local -r tool_name="${FUNCNAME[0]:-${funcstack[1]}}"
  local -r image="${ALIEN_REPOSITORY}:${tool_name}"

  if { [ -n "${ZSH_VERSION:-}" ] && whence -cp "${tool_name}" &>/dev/null; } \
    || { type -P "${tool_name}" &>/dev/null; }; then
    # shellcheck disable=SC2068  # Double quote array expansions
    # shellcheck disable=SC2086  # quote this to prevent word splitting
    command ${tool_name} ${@}
    return ${?}
  fi

  local -r state="$(
    docker inspect --format '{{.State.Running}}' "${tool_name}" 2>/dev/null
  )"
  if [ "${state}" = 'true' ]; then
    echo >&2 "There's already an instance of \"${tool_name}\" running."
    return 1
  fi

  docker run \
    --name "${tool_name}" \
    --rm \
    --interactive \
    --env SHELLCHECK_OPTS \
    --volume "${SHELLCHECK_DIR:-${PWD}}:/mnt" \
    "${image}" "${@}"
}

## shfmt (https://github.com/mvdan/sh)
##
## e.g. shfmt -l -w <script-file>
function shfmt() {
  local -r tool_name="${FUNCNAME[0]:-${funcstack[1]}}"
  local -r image="${ALIEN_REPOSITORY}:${tool_name}"

  if { [ -n "${ZSH_VERSION:-}" ] && whence -cp "${tool_name}" &>/dev/null; } \
    || { type -P "${tool_name}" &>/dev/null; }; then
    # shellcheck disable=SC2068  # Double quote array expansions
    # shellcheck disable=SC2086  # quote this to prevent word splitting
    command ${tool_name} -i 2 -ci -bn ${@}
    return ${?}
  fi

  local -r state="$(
    docker inspect --format '{{.State.Running}}' "${tool_name}" 2>/dev/null
  )"
  if [ "${state}" = 'true' ]; then
    echo >&2 "There's already an instance of \"${tool_name}\" running."
    return 1
  fi

  docker run \
    --name "${tool_name}" \
    --rm \
    --interactive \
    --volume "${SHFMT_DIR:-${PWD}}:/mnt" \
    "${image}" -i 2 -ci -bn "${@}"
}

## Web page to image - P2I
## https://github.com/hpedrorodrigues/sphynx/blob/main/.alien/p2i/README.md
##
## e.g.
##
## p2i \
##   --url "https://www.google.com/search?q=car+meaning" \
##   --selector '.lr_container' \
##   --filename "car-meaning.png"
function p2i() {
  local -r tool_name="${FUNCNAME[0]:-${funcstack[1]}}"
  local -r image="${ALIEN_REPOSITORY}:${tool_name}"

  local -r state="$(
    docker inspect --format '{{.State.Running}}' "${tool_name}" 2>/dev/null
  )"
  if [ "${state}" = 'true' ]; then
    echo >&2 "There's already an instance of \"${tool_name}\" running."
    return 1
  fi

  docker run \
    --name "${tool_name}" \
    --rm \
    --security-opt seccomp="${SPHYNX_DIR}/.alien/p2i/chrome.json" \
    --volume "${P2I_DIR:-${PWD}}:/mnt" \
    "${image}" "${@}"
}
