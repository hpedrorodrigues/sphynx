#!/usr/bin/env bash

function sx::sqlite::check_requirements() {
  sx::persistence::check_requirements
  sx::require 'sqlite3'
}

function sx::sqlite::run_query() {
  sx::sqlite::check_requirements

  local -r database_file="${1}"
  local -r query="${2}"

  if [ -f "${database_file}" ]; then
    echo "${query}" | sqlite3 "${database_file}"
  else
    sx::log::fatal 'No such file'
  fi
}
