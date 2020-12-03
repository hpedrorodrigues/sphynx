#!/usr/bin/env bash

function sx::android::analyze_apk() {
  sx::android::check_requirements

  local -r path="${1}"

  sx::android::aapt dump badging "${path}"
}

function sx::android::analyze_app() {
  sx::android::check_requirements

  local -r filter="${1}"
  local -r package="$(sx::android::find_package "${filter}")"

  sx::android::ensure_package_exists "${filter}"

  sx::android::pull_apk "${package}"

  echo

  local -r apk_name="$(sx::android::find_apk_name_by_package "${package}")"

  sx::android::analyze_apk "${apk_name}"
}
