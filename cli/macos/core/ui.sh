#!/usr/bin/env bash

function sx::macos::ensure_valid_state() {
  local -r state="${1}"

  if [ "${state}" != 'on' ] && [ "${state}" != 'off' ]; then
    sx::log::fatal "Invalid state provided \"${state}\". Possible (on|off)."
  fi
}

function sx::macos::kill_finder() {
  killall Finder '/System/Library/CoreServices/Finder.app'
}

function sx::macos::show_hidden_files() {
  sx::macos::check_requirements

  local -r state="${1}"

  sx::macos::ensure_valid_state "${state}"

  local -r apple_state="$([ "${state}" = 'on' ] && echo 'YES' || echo 'NO')"

  defaults write com.apple.finder AppleShowAllFiles "${apple_state}"

  sx::macos::kill_finder
}

function sx::macos::change_spotlight_indexing_state() {
  sx::macos::check_requirements

  local -r state="${1}"

  sx::macos::ensure_valid_state "${state}"

  sudo mdutil -a -i "${state}"
}
