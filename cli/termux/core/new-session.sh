#!/usr/bin/env bash

function sx::termux::new-session() {
  sx::require 'adb'

  adb root
  adb shell am start -n com.termux/.HomeActivity

  adb forward tcp:8022 tcp:8022
  ssh localhost -p 8022
}
