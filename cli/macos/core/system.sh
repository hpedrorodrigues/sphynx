#!/usr/bin/env bash

function sx::osx::change_screenshots_path() {
  sx::require_osx

  local -r new_path="${1}"

  mkdir -p "${new_path}"

  defaults write com.apple.screencapture location "${new_path}"

  sx::osx::restart_ui
}

function sx::osx::delete_index_files() {
  sx::require_osx

  find . -name '*.DS_Store' -type f -ls -delete
}

function sx::osx::current_wifi_password() {
  sx::require_osx

  local -r ssid="$(sx::network::current::ssid)"

  if [ -z "${ssid}" ]; then
    sx::log::fatal 'Could not retrieve current SSID. Are you connected?'
  fi

  sx::osx::keychain_pass "${ssid}"
}
