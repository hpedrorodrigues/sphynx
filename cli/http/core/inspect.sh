#!/usr/bin/env bash

function sx::http::inspect() {
  sx::http::check_requirements
  sx::require 'node'

  local -r port="${1:-}"

  sx::log::info 'Now you can make requests in order to inspect their content.\n'
  PORT="${port}" node "${SPHYNXN_DIR}/code/server.js"
}