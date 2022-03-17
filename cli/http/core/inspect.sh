#!/usr/bin/env bash

function sx::http::inspect() {
  sx::http::check_requirements
  sx::require 'node'

  local -r port="${1:-}"

  sx::log::info 'Now you can make requests in order to inspect their content.'

  echo "http://127.0.0.1:${port}" | sx::system::clipboard::copy
  sx::log::info 'Server address copied to clipboard!\n'

  PORT="${port}" exec node "${SPHYNXN_DIR}/code/server.js"
}
