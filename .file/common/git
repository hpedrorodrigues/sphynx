#!/usr/bin/env bash

## Aliases

alias g='git'
alias gi='git'

alias gs='git status'
alias gst='git status'
alias gba='git branch --all'

alias gch='sx git check'

alias gbc='sx git branch --clear'
alias gbs='sx git branch --switch'

alias email='sx github email'

# Go to the root folder of a git repository
alias goroot='cd $(git rev-parse --show-toplevel)'

## Functions

function repo() {
  sx git open "${*}"
}

function ggpull() {
  local -r current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"

  if [ -z "${current_branch}" ]; then
    echo '!!! You are running this command outside a git repository' >&2
    return 1
  fi

  git pull origin "${current_branch}" "${@}"
}

function ggpush() {
  local -r current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"

  if [ -z "${current_branch}" ]; then
    echo '!!! You are running this command outside a git repository' >&2
    return 1
  fi

  git push origin "${current_branch}" "${@}"
}

function gu() {
  local -r current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"

  if [ -z "${current_branch}" ]; then
    echo '!!! You are running this command outside a git repository' >&2
    return 1
  fi

  git fetch origin --prune && git pull origin "${current_branch}"
}
