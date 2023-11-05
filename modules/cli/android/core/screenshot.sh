#!/usr/bin/env bash

function sx::android::screenshot::take() {
  sx::android::check_requirements

  local -r day="$(date +%d-%m-%y)"
  local -r hour="$(date +%H.%M.%S)"
  local -r file_name="${1:-Screenshot ${day} at ${hour}.png}"

  sx::android::shell screencap -p >"${file_name}"
  sx::log::info "Screenshot \"$file_name\" saved"
}
