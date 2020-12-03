#!/usr/bin/env bash

function sx::android::bundle() {
  local -r bundle_path="${1}"
  local -r must_install="${2:-false}"

  if ! [ -f "${bundle_path}" ]; then
    sx::log::fatal "The file \"${bundle_path}\" doesn't exist"
  fi

  local -r bundle_name="$(basename "${bundle_path}")"
  local -r apk_name="${bundle_name}.apks"

  sx::android::bundletool \
    --bundle "${bundle_path}" \
    --output "${apk_name}"

  if ${must_install}; then
    sx::android::bundletool \
      install-apks \
      --apks "${apk_name}"
  fi
}
