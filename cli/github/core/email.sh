#!/usr/bin/env bash

function sx::github::email() {
  sx::github::check_requirements

  local -r username="${1}"
  local repositories
  readarray -t repositories < <(sx::github::api \
    "users/${username}/repos?type=owner&sort=updated" \
    | jq --raw-output '.[] | select(.fork==false) | .name')

  if [ "${#repositories[@]}" -eq 0 ]; then
    sx::log::fatal "No repositories found for user \"${username}\"."
  fi

  local user_email
  # shellcheck disable=SC2068  # Double quote array expansions
  for repository in ${repositories[@]}; do
    user_email="$(sx::github::api \
      "repos/${username}/${repository}/commits?author=${username}" \
      | jq --raw-output '.[] | .commit.author.email' \
      | sort -u)"

    if [ -n "${user_email}" ]; then
      echo "${user_email}"
      break
    fi
  done
}
