#!/usr/bin/env bash

function sx::android::bundle() {
  sx::require "${SX_BUNDLETOOL_CMD}" 'bundletool'

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
    sx::android::check_requirements "${3:-}"

    local -r serial="$(sx::android::target_device "${3:-}")"

    if [ -n "${serial}" ]; then
      local -r device_flags="--device-id=${serial}"
    else
      local -r device_flags=''
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    sx::android::bundletool \
      install-apks \
      ${device_flags} \
      --apks "${apk_name}"
  fi
}
