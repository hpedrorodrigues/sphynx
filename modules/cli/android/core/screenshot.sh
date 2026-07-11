#!/usr/bin/env bash

function sx::android::screenshot::take() {
  sx::android::check_requirements "${2:-}"

  local -r day="$(date +%d-%m-%y)"
  local -r hour="$(date +%H.%M.%S)"
  local -r file_name="${1:-Screenshot ${day} at ${hour}.png}"
  local -r serial="$(sx::android::target_device "${2:-}")"

  sx::android::shell "${serial}" screencap -p >"${file_name}"
  sx::log::info "Screenshot \"$file_name\" saved"
}
