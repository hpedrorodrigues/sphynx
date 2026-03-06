#!/usr/bin/env bash

function sx::github::email() {
  sx::github::check_requirements

  local -r username="${1}"
  local -r repos_response="$(sx::github::api "users/${username}/repos?type=owner&sort=updated")"

  if ! echo "${repos_response}" | jq --exit-status 'type == "array"' &>/dev/null; then
    local -r api_message="$(echo "${repos_response}" | jq --raw-output '.message // empty')"
    sx::log::fatal "${api_message:-"Unexpected API response for user \"${username}\"."}"
  fi

  local repositories
  readarray -t repositories < <(echo "${repos_response}" \
    | jq --raw-output '.[] | select(.fork==false) | .name')

  if [ "${#repositories[@]}" -eq 0 ]; then
    sx::log::fatal "No repositories found for user \"${username}\"."
  fi

  local user_email
  # shellcheck disable=SC2068  # Double quote array expansions
  for repository in ${repositories[@]}; do
    user_email="$(sx::github::api \
      "repos/${username}/${repository}/commits?author=${username}" \
      | jq --raw-output 'if type == "array" then .[] | .commit.author.email else empty end' \
      | sort -u)"

    if [ -n "${user_email}" ]; then
      echo "${user_email}"
    fi
  done
}
