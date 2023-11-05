#!/usr/bin/env bash

export SPHYNX_VERBOSE="${SPHYNX_VERBOSE:-false}"

function sx::log::is_verbose() {
  [ -n "${SPHYNX_VERBOSE}" ] && [ "${SPHYNX_VERBOSE}" = 'true' ]
}

# Like sx::log::info, but only works in verbose mode
function sx::log::verbose() {
  if ! sx::log::is_verbose; then
    return
  fi

  sx::log::info "${*}"
}

# Like sx::log::info, but without \n, so you can make a progress bar
function sx::log::progress() {
  local message

  for message; do
    echo -e -n "${message}"
  done
}

function sx::log::info() {
  local message

  for message; do
    echo -e "${message}"
  done
}

function sx::log::err() {
  local message

  for message; do
    sx::log::errn "!!! ${message}"
  done
}

function sx::log::errn() {
  local message

  for message; do
    echo -e "${message}" >&2
  done
}

function sx::log::fatal() {
  local -r message="${1:-}"
  local -r code="${2:-1}"
  local stack_skip=${3:-0}

  if sx::log::is_verbose; then
    stack_skip=$((stack_skip + 1))

    local -r source_file="${BASH_SOURCE[${stack_skip}]}"
    local -r source_line="${BASH_LINENO[$((stack_skip - 1))]}"

    sx::log::err "Error in ${source_file}:${source_line}"

    [[ -z ${message-} ]] || {
      sx::log::errn "    ${message}"
    }

    sx::log::stack ${stack_skip}

    sx::log::errn "Exiting with status ${code}"
  else
    [ -n "${message}" ] && sx::log::err "${message}"
  fi

  exit "${code}"
}

function sx::log::stack() {
  local stack_skip=${1:-0}

  stack_skip=$((stack_skip + 1))

  if [[ ${#FUNCNAME[@]} -gt ${stack_skip} ]]; then
    sx::log::errn 'Call stack:'

    local i
    for ((i = 1; i <= ${#FUNCNAME[@]} - stack_skip; i++)); do
      local frame_no="$((i - 1 + stack_skip))"
      local source_file="${BASH_SOURCE[${frame_no}]}"
      local source_lineno="${BASH_LINENO[$((frame_no - 1))]}"
      local funcname="${FUNCNAME[${frame_no}]}"

      sx::log::errn "  ${i}: ${source_file}:${source_lineno} ${funcname}(...)"
    done
  fi
}
