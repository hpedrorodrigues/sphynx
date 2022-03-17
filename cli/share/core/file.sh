#!/usr/bin/env bash

export TRANSFER_URL='https://transfer.sh'

function sx::share::file() {
  sx::require_supported_os
  sx::require_network

  local -r file_path="${1:-}"

  if ! [ -f "${file_path}" ]; then
    sx::log::fatal 'No such file'
  fi

  if ! [ -s "${file_path}" ]; then
    sx::log::fatal 'Empty file'
  fi

  local -r file_name="$(
    basename "${file_path}" \
      | sed -e 's/[^a-zA-Z0-9._-]/-/g'
  )"

  local -r transfer_response="$(
    curl \
      --silent \
      --include \
      --upload-file "${file_path}" \
      "${TRANSFER_URL}/${file_name}"
  )"

  local -r status_code="$(echo "${transfer_response}" | head -n1 | awk '{ print $2 }')"
  local -r body="$(echo "${transfer_response}" | tail -n1)"

  if [ "${status_code}" != '200' ]; then
    sx::log::errn 'Error occurred sharing file:\n'
    sx::log::err "Status: ${status_code}"
    sx::log::err 'Body:'
    sx::log::fatal "${body}"
  fi

  local -r file_url="${body}"

  sx::log::info "> File URL: ${file_url}\n"

  echo "${file_url}" | sx::system::clipboard::copy
  sx::log::info 'URL copied to clipboard!'
}
