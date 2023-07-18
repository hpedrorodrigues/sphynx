#!/usr/bin/env bash

## Function to help me handle the Sphynx repository
##
## e.g. sphynx code
## e.g. sphynx status
function sphynx() {
  local -r action="${1}"
  local -r sphynx_repository="${HOME}/Code/Personal/sphynx"

  if [ "${action}" = 'code' ]; then
    code "${sphynx_repository}"
  elif [ "${action}" = 'go' ]; then
    cd "${sphynx_repository}" || return 1
  elif [ "${action}" = 'status' ]; then
    (cd "${sphynx_repository}" && git status)
  elif [ "${action}" = 'repo' ]; then
    (cd "${sphynx_repository}" && sx git open)
  elif [ "${action}" = 'run' ]; then
    # shellcheck disable=SC2068  # Double quote array expansions
    (cd "${secrets_repository}" && ${@:2})
  else
    if [ -z "${action}" ]; then
      echo "!!! No action provided." >&2
    else
      echo "!!! No supported action: \"${action}\"" >&2
    fi
    echo '!!!' >&2
    echo '!!! Available actions' >&2
    echo '!!!   - code' >&2
    echo '!!!   - go' >&2
    echo '!!!   - status' >&2
    echo '!!!   - repo' >&2
    echo '!!!   - run' >&2
    return 1
  fi
}

## Function to help me handle the secrets repository
##
## e.g. secrets code
## e.g. secrets push
function secrets() {
  local -r action="${1}"
  local -r secrets_repository="${HOME}/Code/Personal/secrets"

  if [ "${action}" = 'code' ]; then
    code "${secrets_repository}"
  elif [ "${action}" = 'go' ]; then
    cd "${secrets_repository}" || return 1
  elif [ "${action}" = 'status' ]; then
    (cd "${secrets_repository}" && git status)
  elif [ "${action}" = 'pull' ]; then
    (
      cd "${secrets_repository}" \
        && git add -A \
        && git stash \
        && ggpull \
        && git stash apply
    )
  elif [ "${action}" = 'push' ]; then
    (
      cd "${secrets_repository}" \
        && git add -A \
        && git commit -m '[CLI] Updating Secrets' \
        && ggpush
    )
  elif [ "${action}" = 'repo' ]; then
    (cd "${secrets_repository}" && sx git open)
  elif [ "${action}" = 'run' ]; then
    # shellcheck disable=SC2068  # Double quote array expansions
    (cd "${secrets_repository}" && ${@:2})
  else
    if [ -z "${action}" ]; then
      echo "!!! No action provided." >&2
    else
      echo "!!! No supported action: \"${action}\"" >&2
    fi
    echo '!!!' >&2
    echo '!!! Available actions' >&2
    echo '!!!   - code' >&2
    echo '!!!   - go' >&2
    echo '!!!   - status' >&2
    echo '!!!   - pull' >&2
    echo '!!!   - push' >&2
    echo '!!!   - repo' >&2
    echo '!!!   - run' >&2
    return 1
  fi
}
