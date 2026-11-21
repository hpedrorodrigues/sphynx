#!/usr/bin/env bash

function sx::aws::profile::list() {
  sx::aws::check_requirements

  sx::aws_command::list_profiles
}

function sx::aws::profile::switch() {
  sx::aws::check_requirements

  local -r query="${1:-}"

  local -r options="$(sx::aws_command::list_profiles "${query}")"

  if [ -z "${options}" ]; then
    sx::log::fatal 'No profiles found'
  fi

  local -r selected="$(sx::select_one 'Please, choose the profile' <<<"${options}")"

  if [ -n "${selected}" ]; then
    echo "export AWS_PROFILE=\"${selected}\""
  fi
}

function sx::aws_command::list_profiles() {
  local -r query="${1:-}"

  if [ -n "${query}" ]; then
    local -r selector="$(echo "${query}" | sx::string::lowercase)"
  else
    local -r selector='.*'
  fi

  local -r profiles="$(
    aws configure list-profiles \
      | sx::string::lowercase \
      | grep -E "${selector}"
  )"

  # shellcheck disable=SC2068  # Double quote array expansions
  for profile in ${profiles[@]}; do
    if [ "${profile}" = "${AWS_PROFILE:-}" ]; then
      sx::color::current_item::echo "${profile}"
    else
      echo "${profile}"
    fi
  done
}
