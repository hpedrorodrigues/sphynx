#!/usr/bin/env bash

# External images

export CONFLUENT_VERSION=${CONFLUENT_VERSION:-7.5.0}

## Kafka CLI (https://kafka.apache.org)
##
## e.g. kcli kafka-topics --bootstrap-server <host>:<port> --list
## e.g. kcli kafka-console-consumer --bootstrap-server <host>:<port> --topic <topic-name> --from-beginning
function kcli() {
  local -r tool_name="${FUNCNAME[0]:-${funcstack[1]}}"
  local -r random_port="$(shuf -i 2000-65000 -n 1)"

  if ! hash 'docker' 2>/dev/null; then
    echo 'The command-line \"docker\" is not available in your path' >&2
    return 1
  fi

  local -r state="$(
    docker inspect --format '{{.State.Running}}' "${tool_name}" 2>/dev/null
  )"
  if [ "${state}" = 'true' ]; then
    echo "There's already an instance of \"${tool_name}\" running." >&2
    return 1
  fi

  docker run \
    --rm \
    --name "${tool_name}" \
    --interactive \
    --publish "${random_port}:9092" \
    --volume "${KCLI_DIR:-${PWD}}:/mnt" \
    "confluentinc/cp-kafka:${CONFLUENT_VERSION}" "${@}"
}

# Sphynx images

export DOCKER_REPOSITORY="${DOCKER_REPOSITORY:-hpedrorodrigues/alien}"

## Prettier (https://prettier.io)
##
## e.g. prettier --check '*/**/*.{yml,yaml}'
function prettier() {
  local -r tool_name="${FUNCNAME[0]:-${funcstack[1]}}"
  local -r image="${DOCKER_REPOSITORY}:${tool_name}"

  if { [ -n "${ZSH_VERSION:-}" ] && whence -cp "${tool_name}" &>/dev/null; } \
    || { type -P "${tool_name}" &>/dev/null; }; then
    # shellcheck disable=SC2068  # Double quote array expansions
    # shellcheck disable=SC2086  # quote this to prevent word splitting
    command ${tool_name} ${@}
    return ${?}
  elif ! hash 'docker' 2>/dev/null; then
    echo 'The command-line \"docker\" is not available in your path' >&2
    return 1
  else
    local -r state="$(
      docker inspect --format '{{.State.Running}}' "${tool_name}" 2>/dev/null
    )"
    if [ "${state}" = 'true' ]; then
      echo "There's already an instance of \"${tool_name}\" running." >&2
      return 1
    fi

    docker run \
      --name "${tool_name}" \
      --rm \
      --interactive \
      --volume "${PRETTIER_DIR:-${PWD}}:/mnt" \
      "${image}" "${@}"
  fi
}

## Hadolint (https://github.com/hadolint/hadolint)
##
## e.g. hadolint < <path-to-Dockerfile>
function hadolint() {
  local -r tool_name="${FUNCNAME[0]:-${funcstack[1]}}"
  local -r image="${DOCKER_REPOSITORY}:${tool_name}"

  if { [ -n "${ZSH_VERSION:-}" ] && whence -cp "${tool_name}" &>/dev/null; } \
    || { type -P "${tool_name}" &>/dev/null; }; then
    # shellcheck disable=SC2068  # Double quote array expansions
    # shellcheck disable=SC2086  # quote this to prevent word splitting
    command ${tool_name} ${@}
    return ${?}
  elif ! hash 'docker' 2>/dev/null; then
    echo 'The command-line \"docker\" is not available in your path' >&2
    return 1
  else
    local -r state="$(
      docker inspect --format '{{.State.Running}}' "${tool_name}" 2>/dev/null
    )"
    if [ "${state}" = 'true' ]; then
      echo "There's already an instance of \"${tool_name}\" running." >&2
      return 1
    fi

    docker run \
      --name "${tool_name}" \
      --rm \
      --interactive \
      --volume "${HADOLINT_DIR:-${PWD}}:/mnt" \
      "${image}" "${@}"
  fi
}

## ShellCheck (https://github.com/koalaman/shellcheck)
##
## e.g. shellcheck <script-file>
function shellcheck() {
  local -r tool_name="${FUNCNAME[0]:-${funcstack[1]}}"
  local -r image="${DOCKER_REPOSITORY}:${tool_name}"

  if { [ -n "${ZSH_VERSION:-}" ] && whence -cp "${tool_name}" &>/dev/null; } \
    || { type -P "${tool_name}" &>/dev/null; }; then
    # shellcheck disable=SC2068  # Double quote array expansions
    # shellcheck disable=SC2086  # quote this to prevent word splitting
    command ${tool_name} ${@}
    return ${?}
  elif ! hash 'docker' 2>/dev/null; then
    echo 'The command-line \"docker\" is not available in your path' >&2
    return 1
  else
    local -r state="$(
      docker inspect --format '{{.State.Running}}' "${tool_name}" 2>/dev/null
    )"
    if [ "${state}" = 'true' ]; then
      echo "There's already an instance of \"${tool_name}\" running." >&2
      return 1
    fi

    docker run \
      --name "${tool_name}" \
      --rm \
      --interactive \
      --env SHELLCHECK_OPTS \
      --volume "${SHELLCHECK_DIR:-${PWD}}:/mnt" \
      "${image}" "${@}"
  fi
}

## shfmt (https://github.com/mvdan/sh)
##
## e.g. shfmt -l -w <script-file>
function shfmt() {
  local -r tool_name="${FUNCNAME[0]:-${funcstack[1]}}"
  local -r image="${DOCKER_REPOSITORY}:${tool_name}"

  if { [ -n "${ZSH_VERSION:-}" ] && whence -cp "${tool_name}" &>/dev/null; } \
    || { type -P "${tool_name}" &>/dev/null; }; then
    # shellcheck disable=SC2068  # Double quote array expansions
    # shellcheck disable=SC2086  # quote this to prevent word splitting
    command ${tool_name} -i 2 -ci -bn ${@}
    return ${?}
  elif ! hash 'docker' 2>/dev/null; then
    echo 'The command-line \"docker\" is not available in your path' >&2
    return 1
  else
    local -r state="$(
      docker inspect --format '{{.State.Running}}' "${tool_name}" 2>/dev/null
    )"
    if [ "${state}" = 'true' ]; then
      echo "There's already an instance of \"${tool_name}\" running." >&2
      return 1
    fi

    docker run \
      --name "${tool_name}" \
      --rm \
      --interactive \
      --volume "${SHFMT_DIR:-${PWD}}:/mnt" \
      "${image}" -i 2 -ci -bn "${@}"
  fi
}