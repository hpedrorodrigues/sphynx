#!/usr/bin/env bash

function sx::os::is_osx() {
  [ "$(uname)" = 'Darwin' ]
}

function sx::os::is_linux() {
  [ "$(uname)" = 'Linux' ]
}

function sx::os::ensure_supported_os() {
  if ! sx::os::is_osx && ! sx::os::is_linux; then
    sx::log::fatal 'You are not running on a supported OS'
  fi
}

function sx::os::ensure_osx() {
  if ! sx::os::is_osx; then
    sx::log::fatal 'You are not running on a MacOS machine'
  fi
}

function sx::os::ensure_linux() {
  if ! sx::os::is_linux; then
    sx::log::fatal 'You are not running on a Linux machine'
  fi
}

function sx::os::is_command_available() {
  local -r command="${1:-}"

  if [ -z "${command}" ]; then
    sx::log::fatal 'You must provide a command to this function'
  fi

  hash "${command}" 2>/dev/null
}

function sx::os::open() {
  local -r open_commands=(
    'xdg-open'
    'gnome-open'
    'open'
  )

  for open_command in "${open_commands[@]}"; do
    if sx::os::is_command_available "${open_command}"; then
      exec "${open_command}" "${*}" &>/dev/null
    fi
  done

  sx::log::fatal "No command-line utility available to open: \"${*}\""
}

function sx::os::browser::open() {
  if [ -n "${BROWSER:-}" ]; then
    exec "${BROWSER}" "${*}" &>/dev/null
  fi

  local -r browser_commands=(
    'x-www-browser'
    'www-browser'
    'gnome-www-browser'
    'sensible-browser'
    'chrome'
    'google-chrome'
    'google-chrome-stable'
    'firefox'
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
    '/Applications/Firefox Developer Edition.app/Contents/MacOS/firefox'
    '/Applications/Firefox.app/Contents/MacOS/firefox'
  )

  for browser_command in "${browser_commands[@]}"; do
    if sx::os::is_command_available "${browser_command}"; then
      exec "${browser_command}" "${*}" &>/dev/null
    fi
  done

  sx::os::open "${*}"
}
