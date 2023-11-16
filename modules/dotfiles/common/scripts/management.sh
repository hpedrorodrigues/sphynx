#!/usr/bin/env bash

## Base function to help me handle personal projects
##
## e.g. management <directory> <action>
function management() {
  local -r directory="${1:-}"
  local -r action="${2:-}"

  if [ -z "${directory}" ]; then
    echo "!!! No directory provided." >&2
    return 1
  fi

  if [ -z "${action}" ]; then
    echo "!!! No action provided." >&2
    return 1
  fi

  case "${action}" in
    code)
      code "${directory}"
      ;;
    go | j | jump)
      cd "${directory}" || return 1
      ;;
    status)
      (cd "${directory}" && git status)
      ;;
    repo)
      (cd "${directory}" && sx git open)
      ;;
    run)
      # shellcheck disable=SC2068  # Double quote array expansions
      (cd "${directory}" && ${@:3})
      ;;
    pull)
      (
        cd "${directory}" \
          && git add -A \
          && git stash \
          && ggpull \
          && git stash apply
      )
      ;;
    push)
      (
        cd "${directory}" \
          && git add -A \
          && git commit -m "[Auto] Updating" \
          && ggpush
      )
      ;;
    *)
      echo "!!! No supported action: \"${action}\"" >&2
      echo '!!!' >&2
      echo '!!! Available actions:' >&2
      echo '!!!   - code' >&2
      echo '!!!   - go | j | jump' >&2
      echo '!!!   - status' >&2
      echo '!!!   - repo' >&2
      echo '!!!   - run' >&2
      echo '!!!   - pull' >&2
      echo '!!!   - push' >&2
      return 1
      ;;
  esac
}

## Function to help me handle the sphynx repository
##
## e.g. sphynx code
## e.g. sphynx status
function sphynx() {
  # shellcheck disable=SC2086  # quote this to prevent word splitting
  # shellcheck disable=SC2048  # Use "$@" (with quotes) to prevent whitespace problems
  management "${HOME}/Code/Personal/sphynx" ${*}
}

## Function to help me handle the secrets repository
##
## e.g. secrets code
## e.g. secrets push
function secrets() {
  # shellcheck disable=SC2086  # quote this to prevent word splitting
  # shellcheck disable=SC2048  # Use "$@" (with quotes) to prevent whitespace problems
  management "${HOME}/Code/Personal/secrets" ${*}
}
