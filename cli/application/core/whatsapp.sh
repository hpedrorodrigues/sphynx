#!/usr/bin/env bash

export WHATSAPP_LONG_URL='https://api.whatsapp.com/send/?phone='
export WHATSAPP_SHORT_URL='https://wa.me/'

function sx::whatsapp::open() {
  sx::require_supported_os

  local -r phone_number="${1}"
  sx::whatsapp::ensure_valid_phone_number "${phone_number}"

  local -r full_long_url="${WHATSAPP_LONG_URL}${phone_number}"
  local -r full_short_url="${WHATSAPP_SHORT_URL}${phone_number}"

  sx::log::info 'You can use the following URLs to share this phone number.\n'
  sx::log::info "- ${full_long_url}"
  sx::log::info "- ${full_short_url}"

  sx::os::browser::open "${full_long_url}"
}
