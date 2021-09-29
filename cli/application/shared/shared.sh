#!/usr/bin/env bash

function sx::whatsapp::is_valid_phone_number() {
  local -r phone_number="${1}"

  if [ -z "${phone_number}" ]; then
    sx::log::fatal 'No phone number provided'
  fi

  [[ "${phone_number}" =~ ^\+[0-9]{11,13}$ ]]
}

function sx::whatsapp::ensure_valid_phone_number() {
  local -r phone_number="${1}"

  if ! sx::whatsapp::is_valid_phone_number "${phone_number}"; then
    sx::log::errn "\"${phone_number}\" is not a valid phone number.\n"
    sx::log::err 'Please use the following format: +<country-code><ddd><phone-number>'
    sx::log::err 'e.g. +5511999991111'
    sx::log::fatal 'e.g. +19991119999'
  fi
}
