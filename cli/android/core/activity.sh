#!/usr/bin/env bash

function sx::android::activity::current() {
  sx::android::check_requirements

  local -r name="$(sx::android::shell dumpsys activity activities \
    | grep mResumedActivity \
    | awk '{ print $4 }')"

  sx::log::info "Current activity: \"${name}\""
}
