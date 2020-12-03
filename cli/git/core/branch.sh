#!/usr/bin/env bash

function sx::git::branches() {
  local -r current_branch="$(sx::git::current_branch)"

  git branch -a \
    | sed 's/\**\ *//g' \
    | sed 's/remotes\/origin\///' \
    | sed 's/remotes\/upstream\///' \
    | sed 's/remotes\///' \
    | grep -v -E "HEAD|^${current_branch}$" \
    | sort -u
}

function sx::git::branch::delete() {
  sx::git::check_requirements

  local -r branch="${1}"
  local -r current_branch="$(sx::git::current_branch)"

  if [ "${branch}" = 'master' ] || [ "${branch}" = 'main' ]; then
    sx::log::fatal 'Cannot delete the master/main branch'
  elif [ "${branch}" = "${current_branch}" ]; then
    local -r head_ref="$(git symbolic-ref refs/remotes/origin/HEAD \
      | sed 's#^refs/remotes/origin/##')"

    if [ -n "${head_ref}" ] && sx::git::local::branch_exists "${head_ref}"; then
      git switch "${head_ref}"
    elif sx::git::local::branch_exists 'master'; then
      git switch master
    elif sx::git::local::branch_exists 'main'; then
      git switch main
    else
      sx::log::fatal 'Cannot determine the default branch'
    fi
  fi

  if sx::git::local::branch_exists "${branch}"; then
    git branch --delete "${branch}"
  else
    sx::log::err "Branch \"${branch}\" doesn't exist locally"
  fi

  if sx::git::remote::branch_exists "${branch}"; then
    git push origin --delete "${branch}"
  else
    sx::log::err "Branch \"${branch}\" doesn't exist remotely"
  fi
}

function sx::git::branch::delete_all_local() {
  sx::git::check_requirements

  local -r current_branch="$(sx::git::current_branch)"

  git branch \
    | sed 's/\**\ *//g' \
    | grep -v -E "^master$|^main$|^${current_branch}$" \
    | sort -u \
    | xargs -I % git branch -D %
}

function sx::git::branch::switch() {
  sx::git::check_requirements

  if sx::os::is_command_available 'fzf'; then
    local -r options="$(sx::git::branches)"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No branches found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf ${SX_FZF_ARGS})"

    [ -n "${selected}" ] && git switch "${selected}"
  else
    export PS3=$'\n''Please, choose the branch: '$'\n'

    local options
    mapfile -t options < <(sx::git::branches)

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No branches found'
    fi

    select selected in "${options[@]}"; do
      git switch "${selected}"
      break
    done
  fi
}
