#!/usr/bin/env bash

function sx::termux::new-session() {
  local -r ip="${1:-}"

  if [ -z "${ip}" ]; then
    sx::termux::check_requirements

    adb shell am start -n com.termux/.HomeActivity

    adb forward tcp:8022 tcp:8022
    ssh localhost -p 8022
  else
    sx::require 'ssh'

    ssh "${ip}" -p 8022
  fi
}
