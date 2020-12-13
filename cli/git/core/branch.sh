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

  if sx::os::is_command_available 'fzf'; then
    local -r options="$(sx::git::branches "${query}")"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No branches found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf ${SX_FZF_ARGS})"

    [ -n "${selected}" ] && git switch "${selected}"
  else
    export PS3=$'\n''Please, choose the branch: '$'\n'

    local options
    mapfile -t options < <(sx::git::branches "${query}")

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No branches found'
    fi

    select selected in "${options[@]}"; do
      git switch "${selected}"
      break
    done
  fi
}
