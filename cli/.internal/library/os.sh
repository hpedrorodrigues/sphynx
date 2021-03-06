#!/usr/bin/env bash

function sx::os::is_osx() {
  [ "$(uname)" = 'Darwin' ]
}

function sx::os::is_linux() {
  [ "$(uname)" = 'Linux' ]
}

function sx::os::is_command_available() {
  local -r command="${1:-}"

  if [ -z "${command:-}" ]; then
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
      command "${open_command}" "${*}" &>/dev/null &
      return 0
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
      command "${browser_command}" "${*}" &>/dev/null &
      return 0
    fi
  done

  sx::os::open "${*}"
}
