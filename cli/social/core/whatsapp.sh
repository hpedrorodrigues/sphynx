#!/usr/bin/env bash

export WHATSAPP_LONG_URL='https://api.whatsapp.com/send/?phone='
export WHATSAPP_SHORT_URL='https://wa.me/'

function sx::share::whatsapp() {
  sx::require_supported_os

  local -r phone_number="${1:-}"
  local -r text="${2:-}"

  sx::share::phone_number::ensure_valid "${phone_number}"

  if [ -n "${text}" ]; then
    local -r encoded_text="$(sx::url::encode "${text}")"
    local -r full_long_url="${WHATSAPP_LONG_URL}${phone_number}&text=${encoded_text}"
    local -r full_short_url="${WHATSAPP_SHORT_URL}${phone_number}&text=${encoded_text}"
  else
    local -r full_long_url="${WHATSAPP_LONG_URL}${phone_number}"
    local -r full_short_url="${WHATSAPP_SHORT_URL}${phone_number}"
  fi

  sx::log::info 'You can use the following URLs to share this phone number.\n'
  sx::log::info "- ${full_long_url}"
  sx::log::info "- ${full_short_url}"

  sx::os::browser::open "${full_long_url}"
}
