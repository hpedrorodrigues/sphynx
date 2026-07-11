#!/usr/bin/env bash

function sx::android::analyze::apk() {
  sx::require "${SX_AAPT_CMD}" 'aapt'

  local -r path="${1}"

  if ! [ -f "${path}" ]; then
    sx::log::fatal "No such file \"${path}\""
  fi

  sx::android::aapt dump badging "${path}"
}

function sx::android::analyze::app() {
  sx::require "${SX_AAPT_CMD}" 'aapt'
  sx::android::check_requirements "${2:-}"

  local -r query="${1:-}"
  local -r serial="$(sx::android::target_device "${2:-}")"

  local -r package="$(sx::android::select_package "${query}" "${serial}")"

  if [ -z "${package}" ]; then
    return 1
  fi

  sx::android::pull_apk_by_package "${package}" "${serial}"

  echo

  local -r apk_name="$(sx::android::find_apk_name_by_package "${package}")"

  sx::android::analyze::apk "${apk_name}"
}
