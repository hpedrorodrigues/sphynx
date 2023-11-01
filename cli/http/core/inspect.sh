#!/usr/bin/env bash

function sx::http::inspect() {
  sx::http::check_requirements
  sx::require 'node'

  local -r port="${1:-3000}"
  local -r status_code="${2:-}"
  local -r response_body="${3:-}"
  local -r compact_mode="${4:-false}"

  sx::log::info 'Now you can make requests in order to inspect their content.'

  echo -n "http://127.0.0.1:${port}" | sx::system::clipboard::copy
  sx::log::info 'Server address copied to clipboard!\n'

  PORT="${port}" \
    STATUS_CODE="${status_code}" \
    RESPONSE_BODY="${response_body}" \
    COMPACT_MODE="${compact_mode}" \
    exec node "${SPHYNX_NAMESPACE_DIR}/code/server.js"
}
