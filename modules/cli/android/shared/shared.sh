#!/usr/bin/env bash

export SX_ADB_CMD="${SX_ADB_CMD:-adb}"
export SX_AAPT_CMD="${SX_AAPT_CMD:-aapt}"
export SX_BUNDLETOOL_CMD="${SX_BUNDLETOOL_CMD:-bundletool}"

export ANDROID_Q_VERSION='10'
export ANDROID_S_SDK_VERSION='31'

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
  local -r serial="${1:-}"

  if ! sx::os::is_command_available 'adb' \
    && { [ -z "${SX_ADB_CMD:-}" ] || [ "${SX_ADB_CMD:-}" = 'adb' ]; }; then
    sx::log::fatal 'ADB command not found in PATH'
  fi

  if ! sx::android::has_devices_attached; then
    sx::log::fatal "No devices connected or they're either unauthorized or offline"
  fi

  if [ -n "${serial}" ] \
    && ! sx::android::available_devices | awk '{ print $1 }' | grep -q -x -- "${serial}"; then
    sx::log::fatal "No connected device matches the serial \"${serial}\""
  fi
}

function sx::android::target_device() {
  local -r serial="${1:-}"

  if [ -n "${serial}" ]; then
    echo "${serial}"
    return 0
  fi

  if sx::android::has_more_than_one_device_attached; then
    sx::android::select_device
  fi
}

function sx::android::ensure_wifi_enabled() {
  local -r serial="${1:-}"
  local -r wifi_state="$(sx::android::shell "${serial}" dumpsys wifi | grep 'Wi-Fi is')"

  if [ "${wifi_state}" = 'Wi-Fi is disabled' ]; then
    sx::log::fatal 'The WiFi connection of Android device is currently disabled'
  fi
}

function sx::android::list_packages() {
  local -r serial="${1:-}"

  sx::android::has_devices_attached \
    && sx::android::shell "${serial}" pm list packages | sed 's/package://g' | sort -u
}

function sx::android::find_apk_name_by_package() {
  local -r package="${1}"

  echo "${package}" | sed 's/\./_/g' | awk '{ print $1".apk" }'
}

function sx::android::select_one() {
  local candidates
  readarray -t candidates

  if [ "${#candidates[@]}" -eq 0 ]; then
    return 0
  fi

  if sx::os::is_command_available 'fzf'; then
    # shellcheck disable=SC2086  # quote this to prevent word splitting
    printf '%s\n' "${candidates[@]}" | fzf ${SX_FZF_ARGS}
  else
    export PS3=$'\n''Please, choose an option: '$'\n'

    local selected
    select selected in "${candidates[@]}"; do
      if [ -z "${selected}" ]; then
        sx::log::err "Invalid option \"${REPLY}\". Please, type the number of the desired option."
        continue
      fi

      echo "${selected}"
      break
    done </dev/tty
  fi
}

function sx::android::select_package() {
  local -r query="${1:-}"
  local -r serial="${2:-}"

  local candidates
  readarray -t candidates < <(sx::android::list_packages "${serial}" | grep -i -- "${query:-.*}")

  if [ "${#candidates[@]}" -eq 0 ]; then
    sx::log::fatal "No packages found matching \"${query}\""
  fi

  printf '%s\n' "${candidates[@]}" | sx::android::select_one
}

function sx::android::select_device() {
  sx::android::available_devices \
    | awk '{ print $1 }' \
    | sx::android::select_one
}

function sx::android::shell() {
  local -r serial="${1:-}"
  shift

  if [ -n "${serial}" ]; then
    local -r serial_flags="-s ${serial}"
  else
    local -r serial_flags=''
  fi

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  sx::android::adb ${serial_flags} shell "${*}"
}

function sx::android::pidof() {
  local -r serial="${1:-}"
  shift

  sx::android::shell "${serial}" pidof "${*}"
}

function sx::android::os_version() {
  local -r serial="${1:-}"

  sx::android::shell "${serial}" getprop ro.build.version.release
}

function sx::android::sdk_version() {
  local -r serial="${1:-}"

  sx::android::shell "${serial}" getprop ro.build.version.sdk
}
