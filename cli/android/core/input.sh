#!/usr/bin/env bash

function sx::android::input::type_text() {
  sx::android::check_requirements

  local -r text="${*}"

  sx::android::shell input text "${text// /%s}"
}

function sx::android::input::clear_text() {
  sx::android::check_requirements

  sx::android::shell input keyevent KEYCODE_MOVE_END
  sx::android::shell input keyevent --longpress "$(printf 'KEYCODE_DEL %.0s' {1..250})"
}
