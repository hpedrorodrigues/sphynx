#!/usr/bin/env bash

function sx::git::branch::delete_all_local() {
  sx::git::check_requirements

  local -r current_branch="$(sx::git::current_branch)"
  local -r default_branch="$(sx::git::default_branch)"

  git branch \
    | sed 's/\**\ *//g' \
    | grep -v -E "^${default_branch}$|^${current_branch}$" \
    | sort -u \
    | xargs -I % git branch -D %
}

function sx::git::branch::switch() {
  sx::git::check_requirements

  local -r query="${1:-}"

  local -r options="$(sx::git::branches "${query}")"

  if [ -z "${options}" ]; then
    sx::log::fatal 'No branches found'
  fi

  local -r selected="$(sx::select_one 'Please, choose the branch' <<<"${options}")"

  [ -n "${selected}" ] && git switch "${selected}"
}
