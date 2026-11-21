#!/usr/bin/env bash

function sx::android::activity::current() {
  sx::android::check_requirements "${1:-}"

  local -r serial="$(sx::android::target_device "${1:-}")"

  local -r os_version="$(sx::android::os_version "${serial}")"

  local activity_name

  if [ "${os_version}" -lt "${ANDROID_Q_VERSION}" ]; then
    activity_name="$(
      sx::android::shell "${serial}" dumpsys activity activities \
        | grep 'mFocusedActivity' \
        | cut -d . -f 5 \
        | cut -d ' ' -f 1
    )" || true
  else
    activity_name="$(
      sx::android::shell "${serial}" dumpsys activity activities \
        | grep 'mResumedActivity' \
        | awk '{ print $4 }'
    )" || true
  fi

  if [ -z "${activity_name}" ]; then
    activity_name="$(
      sx::android::shell "${serial}" dumpsys activity activities \
        | grep 'mLastPausedActivity' \
        | awk '{ print $4 }' \
        | head -1
    )" || true
  fi

  if [ -n "${activity_name}" ]; then
    sx::log::info "Current activity: \"${activity_name}\""
  else
    sx::log::fatal 'Cannot determine the current activity name'
  fi
}
