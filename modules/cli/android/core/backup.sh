#!/usr/bin/env bash

function sx::android::backup::package() {
  sx::android::check_requirements

  local -r filter="${1}"
  local -r package="$(sx::android::find_package "${filter}")"

  sx::android::ensure_package_exists "${filter}"

  local -r backup_file_name="$(echo "${package}" | sed 's/\./_/g' | awk '{ print $1".adb" }')"

  sx::android::adb backup -f "${backup_file_name}" -noapk "${package}"
}

function sx::android::backup::all() {
  sx::android::check_requirements

  local -r username="$(sx::android::shell pm list users \
    | grep 'UserInfo' \
    | grep 'running' \
    | cut -d ':' -f 2 \
    | perl -pe 's/\n//g' \
    | sx::string::lowercase || echo 'default')"
  local -r day="$(date +%d-%m-%y)"
  local -r hour="$(date +%H_%M_%S)"
  local -r device_model="$(sx::android::shell getprop ro.product.model | sed 's/ /_/g')"
  local -r backup_file_name="${username} ${device_model} ${day} at ${hour}.adb"

  sx::android::adb backup -apk -shared -all -f "${backup_file_name}"
}

function sx::android::backup::restore() {
  sx::android::check_requirements

  local -r file_path="${1}"

  sx::android::adb restore "${file_path}"
}
