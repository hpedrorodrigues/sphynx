#!/usr/bin/env bash

# External images

export CONFLUENT_VERSION=${CONFLUENT_VERSION:-7.6.0}

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

## Prettier (https://prettier.io)
##
## e.g. prettier --check '*/**/*.{yml,yaml}'
function prettier() {
  # shellcheck disable=SC2068  # Double quote array expansions
  docker run \
    --name 'prettier' \
    --rm \
    --interactive \
    --volume "${PWD}:/mnt" \
    ghcr.io/hpedrorodrigues/prettier ${@}
}

## Hadolint (https://github.com/hadolint/hadolint)
##
## e.g. hadolint - --format=tty < <path-to-Dockerfile>
function hadolint() {
  # shellcheck disable=SC2068  # Double quote array expansions
  docker run \
    --name 'hadolint' \
    --rm \
    --interactive \
    --volume "${PWD}:/mnt" \
    ghcr.io/hpedrorodrigues/hadolint ${@}
}

## ShellCheck (https://github.com/koalaman/shellcheck)
##
## e.g. shellcheck <script-file>
function shellcheck() {
  # shellcheck disable=SC2086  # quote this to prevent word splitting
  # shellcheck disable=SC2068  # Double quote array expansions
  docker run \
    --name 'shellcheck' \
    --rm \
    --interactive \
    --volume "${PWD}:/mnt" \
    ghcr.io/hpedrorodrigues/shellcheck ${SHELLCHECK_OPTS:-} ${@}
}

## shfmt (https://github.com/mvdan/sh)
##
## e.g. shfmt -l -w <script-file>
function shfmt() {
  # shellcheck disable=SC2068  # Double quote array expansions
  docker run \
    --name 'shfmt' \
    --rm \
    --interactive \
    --volume "${PWD}:/mnt" \
    ghcr.io/hpedrorodrigues/shfmt -i 2 -ci -bn ${@}
}
