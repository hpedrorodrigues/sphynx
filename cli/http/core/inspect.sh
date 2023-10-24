#!/usr/bin/env bash

function sx::http::inspect() {
  sx::http::check_requirements
  sx::require 'node'

  local -r port="${1:-}"
  local -r status_code="${2:-}"
  local -r response_body="${3:-}"

  sx::log::info 'Now you can make requests in order to inspect their content.'

  echo "http://127.0.0.1:${port}" | sx::system::clipboard::copy
  sx::log::info 'Server address copied to clipboard!\n'

  PORT="${port}" STATUS_CODE="${status_code}" RESPONSE_BODY="${response_body}" \
    exec node "${SPHYNX_NAMESPACE_DIR}/code/server.js"
}
