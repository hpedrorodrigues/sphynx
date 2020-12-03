#!/usr/bin/env bash

function sx::git::current_branch() {
  git rev-parse --abbrev-ref HEAD 2>/dev/null
}

function sx::git::remote::url() {
  git config --get remote.origin.url
}

function sx::git::remote::branch_exists() {
  local -r branch_name="${1}"
  local -r remote_url="$(sx::git::remote::url)"

  [ -n "$(git ls-remote --heads "${remote_url}" "${branch_name}")" ]
}

function sx::git::local::branch_exists() {
  local -r branch_name="${1}"

  git show-branch "${branch_name}" 2>/dev/null
}
