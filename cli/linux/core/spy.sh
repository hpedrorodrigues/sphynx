#!/usr/bin/env bash

function sx::spy::check_requirements() {
  sx::os::ensure_linux
}

function sx::spy::get_processes() {
  ps --no-headers --format 'uname,pid,cmd' ax
}

function sx::spy::nsenter() {
  local -r pid="${1}"

  sudo nsenter --target "${pid}" --all -- sh
}

function sx::spy::strace() {
  local -r pid="${1}"

  sudo strace --attach "${pid}"
}

function sx::spy::namespaces() {
  sx::spy::check_requirements
  sx::require 'nsenter'

  if sx::os::is_command_available 'fzf'; then
    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(sx::spy::get_processes | fzf ${SX_FZF_ARGS})"

    if [ -n "${selected}" ]; then
      local -r pid="$(echo "${selected}" | awk '{ print $2 }')"

      sx::spy::nsenter "${pid}"
    fi
  else
    export PS3=$'\n''Please, choose the process: '$'\n'

    local options
    mapfile -t options < <(sx::spy::get_processes)

    select selected in "${options[@]}"; do
      local -r pid="$(echo "${selected}" | awk '{ print $2 }')"

      sx::spy::nsenter "${pid}"
      break
    done
  fi
}

function sx::spy::syscalls() {
  sx::spy::check_requirements
  sx::require 'strace'

  if sx::os::is_command_available 'fzf'; then
    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(sx::spy::get_processes | fzf ${SX_FZF_ARGS})"

    if [ -n "${selected}" ]; then
      local -r pid="$(echo "${selected}" | awk '{ print $2 }')"

      sx::spy::strace "${pid}"
    fi
  else
    export PS3=$'\n''Please, choose the process: '$'\n'

    local options
    mapfile -t options < <(sx::spy::get_processes)

    select selected in "${options[@]}"; do
      local -r pid="$(echo "${selected}" | awk '{ print $2 }')"

      sx::spy::strace "${pid}"
      break
    done
  fi
}
