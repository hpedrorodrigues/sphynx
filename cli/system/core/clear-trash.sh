#!/usr/bin/env bash

function sx::system::clear_trash() {
  sx::os::ensure_supported_os

  if sx::os::is_osx; then
    sudo rm -rfv /Volumes/*/.Trashes /Volumes/*/.Trash ~/.Trash/* /private/var/log/asl/*.asl

    sqlite3 "${HOME}/Library/Preferences/com.apple.LaunchServices.QuarantineEventsV"* 'delete from LSQuarantineEvent'

    if sx::osx::is_catalina_or_newer; then
      osascript -e 'tell application "Finder" to empty trash'
    fi
  else
    rm -rf "${HOME}/.local/share/Trash/files/"*
  fi
}
