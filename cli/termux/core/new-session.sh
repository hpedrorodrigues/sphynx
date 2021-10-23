#!/usr/bin/env bash

function sx::termux::new-session() {
  sx::termux::check_requirements

  adb shell am start -n com.termux/.HomeActivity

  adb forward tcp:8022 tcp:8022
  ssh localhost -p 8022
}
