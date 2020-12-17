#!/usr/bin/env bash

function sx::git::check_requirements() {
  sx::require_supported_os
  sx::require 'git'

  local -r remote_url="$(sx::git::remote::url)"

  if [ -z "${remote_url}" ]; then
    sx::log::fatal 'You are running this command outside a git repository'
  fi
}

function sx::git::branches() {
  local -r query="${1:-}"

  if [ -n "${query}" ]; then
    local -r selector="$(echo "${query}" | sx::string::lowercase)"
  else
    local -r selector='.*'
  fi

  local -r current_branch="$(sx::git::current_branch)"

  git branch -a \
    | sed 's/\**\ *//g' \
    | sed 's/remotes\/origin\///' \
    | sed 's/remotes\/upstream\///' \
    | sed 's/remotes\///' \
    | grep -v -E "HEAD|^${current_branch}$" \
    | sort -u \
    | grep -E "${selector}" 2>/dev/null
}

function sx::git::default_branch() {
  local -r branches=(
    "$(git config 'init.defaultBranch')"
    "$(git config --global --includes 'init.defaultBranch')"
    'main'
    'master'
  )

  for branch in "${branches[@]}"; do
    if sx::git::local::branch_exists "${branch}"; then
      echo "${branch}"
      break
    fi
  done
}
