#!/usr/bin/env bash

function sx::android::activity::current() {
  sx::android::check_requirements "${1:-}"

  local -r serial="$(sx::android::target_device "${1:-}")"

  local -r os_version="$(sx::android::os_version "${serial}")"

  if [ "${os_version}" -lt "${ANDROID_Q_VERSION}" ]; then
    local activity_name="$(
      sx::android::shell "${serial}" dumpsys activity activities \
        | grep 'mFocusedActivity' \
        | cut -d . -f 5 \
        | cut -d ' ' -f 1
    )"
  else
    local activity_name="$(
      sx::android::shell "${serial}" dumpsys activity activities \
        | grep 'mResumedActivity' \
        | awk '{ print $4 }'
    )"
  fi

  if [ -z "${activity_name}" ]; then
    local activity_name="$(
      sx::android::shell "${serial}" dumpsys activity activities \
        | grep 'mLastPausedActivity' \
        | awk '{ print $4 }' \
        | head -1
    )"
  fi

  if [ -n "${activity_name}" ]; then
    sx::log::info "Current activity: \"${activity_name}\""
  else
    sx::log::fatal 'Cannot determine the current activity name'
  fi
}
