#!/usr/bin/env bash

function sx::osx::ensure_valid_state() {
  local -r state="${1}"

  if [ "${state}" != 'on' ] && [ "${state}" != 'off' ]; then
    sx::log::fatal "Invalid state provided \"${state}\". Possible (on|off)."
  fi
}

function sx::osx::kill_finder() {
  killall Finder '/System/Library/CoreServices/Finder.app'
}

function sx::osx::restart_ui() {
  sx::require_osx

  killall SystemUIServer
}

function sx::osx::show_hidden_files() {
  sx::require_osx

  local -r state="${1}"

  sx::osx::ensure_valid_state "${state}"

  local -r apple_state="$([ "${state}" = 'on' ] && echo 'YES' || echo 'NO')"

  defaults write com.apple.finder AppleShowAllFiles "${apple_state}"

  sx::osx::kill_finder
}

function sx::osx::change_spotlight_indexing_state() {
  sx::require_osx

  local -r state="${1}"

  sx::osx::ensure_valid_state "${state}"

  sudo mdutil -a -i "${state}"
}
