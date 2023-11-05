#!/usr/bin/env bash

# References:
# - https://devmanual.gentoo.org/tasks-reference/completion/index.html
# - https://debian-administration.org/article/316/An_introduction_to_bash_completion_part_1
# - https://debian-administration.org/article/317/An_introduction_to_bash_completion_part_2

completion_dirname="${SPHYNX_DIR:-}/modules/cli/.internal/completion"

function _sx() {
  COMPREPLY=()

  local current_word="${COMP_WORDS[COMP_CWORD]}"
  # shellcheck disable=SC2068  # Double quote array expansions
  local words="$("${completion_dirname}/complete" "${current_word}" ${COMP_WORDS[@]})"

  while IFS=$'\n' read -r line; do
    COMPREPLY+=("${line}")
  done < <(compgen -W "${words}" -- "${current_word}")

  return 0
}

if hash complete &>/dev/null; then
  complete -F _sx sx
fi
