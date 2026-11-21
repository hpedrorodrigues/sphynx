#!/usr/bin/env bash

function sx::spy::check_requirements() {
  sx::linux::check_requirements
}

function sx::spy::namespaces() {
  sx::spy::check_requirements
  sx::require 'nsenter'

  local -r selected="$(sx::spy::get_processes | sx::select_one 'Please, choose the process')"

  if [ -n "${selected}" ]; then
    local -r pid="$(echo "${selected}" | awk '{ print $2 }')"

    sx::spy::nsenter "${pid}"
  fi
}

function sx::spy::syscalls() {
  sx::spy::check_requirements
  sx::require 'strace'

  local -r selected="$(sx::spy::get_processes | sx::select_one 'Please, choose the process')"

  if [ -n "${selected}" ]; then
    local -r pid="$(echo "${selected}" | awk '{ print $2 }')"

    sx::spy::strace "${pid}"
  fi
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
