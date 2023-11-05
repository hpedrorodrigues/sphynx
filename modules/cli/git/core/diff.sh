#!/usr/bin/env bash

function sx::git::diff() {
  sx::git::check_requirements
  sx::require 'fzf'

  local -r diff_flags="${1:-}"
  local -r git_pager="$(git config core.pager || echo 'cat')"
  local -r cmd="echo ''{}'' | awk '{ print \$2 }' | xargs -I % git diff --color=always ${diff_flags} % | ${git_pager}"

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  git diff --name-status ${diff_flags} \
    | sed -E 's/^(.)[[:space:]]+(.+)$/[\1] \2/' \
    | fzf \
      --no-multi \
      --exit-0 \
      --ansi \
      --cycle \
      --bind="enter:execute(${cmd} | LESS='' less -R)" \
      --preview="${cmd}"
}
