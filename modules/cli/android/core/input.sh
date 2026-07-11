#!/usr/bin/env bash

function sx::android::input::type_text() {
  sx::android::check_requirements "${2:-}"

  local -r text="${1}"
  local -r serial="$(sx::android::target_device "${2:-}")"

  sx::android::shell "${serial}" input text "${text// /%s}"
}

function sx::android::input::clear_text() {
  sx::android::check_requirements "${1:-}"

  local -r serial="$(sx::android::target_device "${1:-}")"
  local -r sdk_version="$(sx::android::sdk_version "${serial}")"

  if [ "${sdk_version}" -ge "${ANDROID_S_SDK_VERSION}" ]; then
    sx::android::shell "${serial}" input keycombination KEYCODE_CTRL_LEFT KEYCODE_A
    sx::android::shell "${serial}" input keyevent KEYCODE_DEL
  else
    sx::android::shell "${serial}" input keyevent KEYCODE_MOVE_END
    sx::android::shell "${serial}" input keyevent --longpress "$(printf 'KEYCODE_DEL %.0s' {1..250})"
  fi
}
