#!/usr/bin/env bash

function sx::uuid() {
  sx::require_supported_os

  local -r id="$(uuidgen)"

  if sx::os::is_macos; then
    sx::log::info "${id}"
  else
    sx::log::info "${id^^}"
  fi
}
