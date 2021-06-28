#!/usr/bin/env bash

function sx::system::clear_trash() {
  sx::system::check_requirements

  if sx::os::is_osx; then
    sx::require 'sqlite3'

    for log_file in /private/var/log/asl/*.asl; do
      if ! [ -f "${log_file}" ]; then
        break
      fi

      rm -rf "${log_file}"
    done

    sqlite3 "${HOME}/Library/Preferences/com.apple.LaunchServices.QuarantineEventsV"* 'delete from LSQuarantineEvent'

    osascript -e '
      tell application "Finder"
        set trashFiles to items in (path to trash folder)
        if (count trashFiles) = 0 then
          return "Trash is empty!"
        else
          empty trash
          return "Done!"
        end if
      end tell
  '
  else
    rm -rf "${HOME}/.local/share/Trash/files/"*
  fi
}
