#!/usr/bin/env bash

function sx::git::check() {
  sx::git::check_requirements

  local -r current_branch="$(sx::git::current_branch)"
  local -r default_branch="$(sx::git::default_branch)"

  local -r last_hash="$(git rev-parse "refs/remotes/origin/${default_branch}^{commit}")"

  if git branch --contains "${last_hash}" | grep -q -E "${current_branch}"; then
    sx::log::info "The current branch (\"${current_branch}\") is up to date with \"${default_branch}\""
  else
    sx::log::fatal "The current branch (\"${current_branch}\") is NOT up to date with \"${default_branch}\""
  fi
}
