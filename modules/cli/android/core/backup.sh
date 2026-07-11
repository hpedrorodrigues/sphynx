#!/usr/bin/env bash

function sx::android::backup::package() {
  sx::android::check_requirements "${2:-}"

  local -r query="${1:-}"
  local -r serial="$(sx::android::target_device "${2:-}")"

  local -r package="$(sx::android::select_package "${query}" "${serial}")"

  if [ -z "${package}" ]; then
    return 1
  fi

  local -r backup_file_name="$(echo "${package}" | sed 's/\./_/g' | awk '{ print $1".adb" }')"

  if [ -n "${serial}" ]; then
    local -r serial_flags="-s ${serial}"
  else
    local -r serial_flags=''
  fi

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  sx::android::adb ${serial_flags} backup -f "${backup_file_name}" -noapk "${package}"
}

function sx::android::backup::all() {
  sx::android::check_requirements "${1:-}"

  local -r serial="$(sx::android::target_device "${1:-}")"

  local -r username="$(sx::android::shell "${serial}" pm list users \
    | grep 'UserInfo' \
    | grep 'running' \
    | cut -d ':' -f 2 \
    | perl -pe 's/\n//g' \
    | sx::string::lowercase || echo 'default')"
  local -r day="$(date +%d-%m-%y)"
  local -r hour="$(date +%H_%M_%S)"
  local -r device_model="$(sx::android::shell "${serial}" getprop ro.product.model | sed 's/ /_/g')"
  local -r backup_file_name="${username} ${device_model} ${day} at ${hour}.adb"

  if [ -n "${serial}" ]; then
    local -r serial_flags="-s ${serial}"
  else
    local -r serial_flags=''
  fi

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  sx::android::adb ${serial_flags} backup -apk -shared -all -f "${backup_file_name}"
}

function sx::android::backup::restore() {
  sx::android::check_requirements "${2:-}"

  local -r file_path="${1}"
  local -r serial="$(sx::android::target_device "${2:-}")"

  if [ -n "${serial}" ]; then
    local -r serial_flags="-s ${serial}"
  else
    local -r serial_flags=''
  fi

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  sx::android::adb ${serial_flags} restore "${file_path}"
}
