#!/usr/bin/env bash

function sx::system::clear_trash() {
  sx::system::check_requirements

  if sx::os::is_osx; then
    sudo rm -rfv /Volumes/*/.Trashes /Volumes/*/.Trash ~/.Trash/* /private/var/log/asl/*.asl

    sqlite3 "${HOME}/Library/Preferences/com.apple.LaunchServices.QuarantineEventsV"* 'delete from LSQuarantineEvent'
  else
    rm -rf "${HOME}/.local/share/Trash/files/"*
  fi
}
