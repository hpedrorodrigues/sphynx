#!/usr/bin/env bash

## Open git repositories/files on browser
##
## e.g. repo
## e.g. repo <path-to-file>
##
## Note: Use "sx git open --help" or "repo --help" for more details
function repo() {
  if ! hash 'sx' 2>/dev/null; then
    echo 'The command-line \"sx\" is not available in your path' >&2
    return 1
  fi

  sx git open "${*}"
}

## Incorporates changes from a remote repository using the current branch as reference
##
## e.g. ggpull
function ggpull() {
  if ! hash 'git' 2>/dev/null; then
    echo 'The command-line \"git\" is not available in your path' >&2
    return 1
  fi

  local -r current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"

  if [ -z "${current_branch}" ]; then
    echo '!!! You are running this command outside a git repository' >&2
    return 1
  fi

  git pull origin "${current_branch}" "${@}"
}

## Updates remote refs using local refs
##
## e.g. ggpush
function ggpush() {
  if ! hash 'git' 2>/dev/null; then
    echo 'The command-line \"git\" is not available in your path' >&2
    return 1
  fi

  local -r current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"

  if [ -z "${current_branch}" ]; then
    echo '!!! You are running this command outside a git repository' >&2
    return 1
  fi

  git push origin "${current_branch}" "${@}"
}

## [Git Update] Fetch for remote changes and apply them into the current branch
##
## e.g. gu
function gu() {
  if ! hash 'git' 2>/dev/null; then
    echo 'The command-line \"git\" is not available in your path' >&2
    return 1
  fi

  local -r current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"

  if [ -z "${current_branch}" ]; then
    echo '!!! You are running this command outside a git repository' >&2
    return 1
  fi

  git fetch origin --prune && git pull origin "${current_branch}"
}
