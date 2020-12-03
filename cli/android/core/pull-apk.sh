#!/usr/bin/env bash

function sx::android::pull_apk() {
  sx::android::check_requirements

  local -r filter="${1}"
  local -r package="$(sx::android::find_package "${filter}")"

  sx::android::ensure_package_exists "${filter}"

  local apk_paths
  mapfile -t apk_paths < <(sx::android::shell pm path "${package}" | sed 's/package://g')

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

  local -r apk_name="$(sx::android::shell basename "${apk_path}")"
  local -r new_apk_name="$(sx::android::find_apk_name_by_package "${package}")"

  sx::android::adb pull "${apk_path}" '.'
  mv "${apk_name}" "${new_apk_name}"

  sx::log::info "APK ${new_apk_name} saved"
}
