#!/usr/bin/env bash

function sx::require() {
  local -r cmd="${1:-}"
  local -r real_cmd_name="${2:-${cmd}}"

  if [ -z "${cmd:-}" ]; then
    sx::log::fatal 'This function needs a command as first argument'
  fi

  if ! sx::os::is_command_available "${cmd}"; then
    sx::log::fatal "The command-line \"${real_cmd_name}\" is not available in your path"
  fi
}

function sx::require_env() {
  local -r env_name="${1:-}"

  if [ -z "${env_name:-}" ]; then
    sx::log::fatal 'This function needs an environment variable as first argument'
  fi

  if [ -z "${!env_name:-}" ]; then
    sx::log::fatal "The environment variable \"${env_name}\" is not set"
  fi
}

function sx::require_network() {
  if ! sx::network::has_connection; then
    sx::log::fatal 'No network connection found'
  fi
}

function sx::require_linux() {
  if ! sx::os::is_linux; then
    sx::log::fatal 'You are not running on a Linux machine'
  fi
}

function sx::require_osx() {
  if ! sx::os::is_osx; then
    sx::log::fatal 'You are not running on a MacOS machine'
  fi
}

function sx::require_supported_os() {
  if ! sx::os::is_osx && ! sx::os::is_linux; then
    sx::log::fatal 'You are not running on a supported OS'
  fi
}
