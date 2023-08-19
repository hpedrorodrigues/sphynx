#!/usr/bin/env bash

readonly operating_systems=('centos' 'ubuntu')

function show_operating_systems() {
  echo "Available OSes:"
  # shellcheck disable=SC2068  # Double quote array expansions
  for operating_system in ${operating_systems[@]}; do
    echo "- ${operating_system}"
  done
}

function check_operating_system() {
  local -r user_os="${1:-}"

  if [ -z "${user_os}" ]; then
    echo >&2 "An operating system is required as first argument."
    echo
    show_operating_systems
    exit 1
  fi

  local is_valid_os=false
  # shellcheck disable=SC2068  # Double quote array expansions
  for operating_system in ${operating_systems[@]}; do
    if [ "${operating_system}" = "${user_os}" ]; then
      is_valid_os=true
      break
    fi
  done

  if ! ${is_valid_os}; then
    echo >&2 "Invalid operating system provided as argument: \"${user_os}\"."
    echo
    show_operating_systems
    exit 1
  fi
}
