#!/usr/bin/env bash

export SX_ADB_CMD="${SX_ADB_CMD:-adb}"
export SX_AAPT_CMD="${SX_AAPT_CMD:-aapt}"
export SX_BUNDLETOOL_CMD="${SX_BUNDLETOOL_CMD:-bundletool}"

export ANDROID_Q_VERSION='10'

function sx::android::adb() {
  "${SX_ADB_CMD}" "${@}"
}

function sx::android::aapt() {
  "${SX_AAPT_CMD}" "${@}"
}

function sx::android::bundletool() {
  "${SX_BUNDLETOOL_CMD}" "${@}"
}

function sx::android::available_devices() {
  sx::android::adb devices \
    | grep -i -v 'list of devices attached\|unauthorized\|offline' \
    | grep -v -E '^[[:space:]]*$'
}

function sx::android::has_devices_attached() {
  local -r n_devices="$(
    sx::android::available_devices | wc -l | tr -d ' ' 2>/dev/null
  )"

  [ "${n_devices}" -gt 0 ]
}

function sx::android::has_more_than_one_device_attached() {
  local -r n_devices="$(
    sx::android::available_devices | wc -l | tr -d ' ' 2>/dev/null
  )"

  [ "${n_devices}" -gt 1 ]
}

function sx::android::check_requirements() {
  if ! sx::os::is_command_available 'adb' \
    && { [ -z "${SX_ADB_CMD:-}" ] || [ "${SX_ADB_CMD:-}" = 'adb' ]; }; then
    sx::log::fatal 'ADB command not found in PATH'
  fi

  if ! sx::android::has_devices_attached; then
    sx::log::fatal "No devices connected or they're either unauthorized or offline"
  fi

  if sx::android::has_more_than_one_device_attached; then
    sx::log::fatal 'More than one device connected'
  fi
}

function sx::android::ensure_wifi_enabled() {
  local -r wifi_state="$(sx::android::shell dumpsys wifi | grep 'Wi-Fi is')"

  if [ "${wifi_state}" = 'Wi-Fi is disabled' ]; then
    sx::log::fatal 'The WiFi connection of Android device is currently disabled'
  fi
}

function sx::android::list_packages() {
  sx::android::has_devices_attached \
    && sx::android::shell pm list packages | sed 's/package://g' | sort -u
}

function sx::android::find_package() {
  local -r filter="${1}"

  sx::android::list_packages | grep -i "${filter}" | head -n 1
}

function sx::android::find_apk_name_by_package() {
  local -r package="${1}"

  echo "${package}" | sed 's/\./_/g' | awk '{ print $1".apk" }'
}

function sx::android::is_package_available() {
  local -r filter="${1}"
  local -r package="$(sx::android::find_package "${filter}")"

  if [ -z "${package}" ]; then
    return 1
  fi

  return 0
}

function sx::android::ensure_package_exists() {
  local -r filter="${1}"
  local -r package="$(sx::android::find_package "${filter}")"

  if [ -z "${package}" ]; then
    sx::log::err "No matches for \"${filter}\""
    sx::log::errn "\n==> Available apps (packages):\n"
    sx::log::errn "$(sx::android::list_packages)"
    sx::log::fatal
  fi
}

function sx::android::shell() {
  sx::android::adb shell "${*}"
}

function sx::android::pidof() {
  sx::android::shell pidof "${*}"
}

function sx::android:os_version() {
  sx::android::shell getprop ro.build.version.release
}

function sx::android::sdk_version() {
  sx::android::shell getprop ro.build.version.sdk
}
