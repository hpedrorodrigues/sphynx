#!/usr/bin/env bash

function sx::macos::change_screenshots_path() {
  sx::macos::check_requirements

  local -r new_path="${1}"

  mkdir -p "${new_path}"

  defaults write com.apple.screencapture location "${new_path}"

  sx::macos::restart_ui
}

function sx::macos::delete_index_files() {
  sx::macos::check_requirements

  find . -name '*.DS_Store' -type f -ls -delete
}

function sx::macos::current_wifi_password() {
  sx::macos::check_requirements

  local -r ssid="$(sx::network::current::ssid)"

  if [ -z "${ssid}" ]; then
    sx::log::fatal 'Could not retrieve current SSID. Are you connected?'
  fi

  sx::osx::keychain_pass "${ssid}"
}
