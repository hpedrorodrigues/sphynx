#!/usr/bin/env bash

function sx::android::pull_apk() {
  sx::android::check_requirements "${2:-}"

  local -r query="${1:-}"
  local -r serial="$(sx::android::target_device "${2:-}")"

  local -r package="$(sx::android::select_package "${query}" "${serial}")"

  if [ -z "${package}" ]; then
    return 1
  fi

  sx::android::pull_apk_by_package "${package}" "${serial}"
}

function sx::android::pull_apk_by_package() {
  local -r package="${1}"
  local -r serial="${2:-}"

  local apk_paths
  readarray -t apk_paths < <(sx::android::shell "${serial}" pm path "${package}" | sed 's/package://g')

  if [ "${#apk_paths[@]}" -eq 1 ]; then
    local -r apk_path="${apk_paths[0]}"
  else
    for path in "${apk_paths[@]}"; do
      if echo "${path}" | grep -q 'base.apk'; then
        local -r apk_path="${path}"
        break
      fi
    done

    if [ -z "${apk_path:-}" ]; then
      sx::log::fatal 'No pullable apk found'
    fi
  fi

  local -r apk_name="$(sx::android::shell "${serial}" basename "${apk_path}")"
  local -r new_apk_name="$(sx::android::find_apk_name_by_package "${package}")"

  if [ -n "${serial}" ]; then
    local -r serial_flags="-s ${serial}"
  else
    local -r serial_flags=''
  fi

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  sx::android::adb ${serial_flags} pull "${apk_path}" '.'
  mv "${apk_name}" "${new_apk_name}"

  sx::log::info "APK ${new_apk_name} saved"
}
