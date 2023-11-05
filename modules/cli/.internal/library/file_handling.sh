#!/usr/bin/env bash

function sx::file::write_replacing() {
  local -r file_path="${1}"
  local -r line_content="${2}"

  if [ -z "${file_path}" ]; then
    sx::log::fatal 'Invalid file (empty)!'
  fi

  if [ -z "${line_content}" ]; then
    sx::log::fatal 'Invalid content (empty)!'
  fi

  echo "${line_content}" >"${file_path}"
}

function sx::file::write_appending() {
  local -r file_path="${1}"
  local -r line_content="${2}"

  if [ -z "${file_path}" ]; then
    sx::log::fatal 'Invalid file (empty)!'
  fi

  if [ -z "${line_content}" ]; then
    sx::log::fatal 'Invalid content (empty)!'
  fi

  echo "${line_content}" >>"${file_path}"
}

function sx::file::read() {
  local -r file_path="${1}"

  if [ -z "${file_path}" ]; then
    sx::log::fatal 'Invalid file (empty)!'
  fi

  # return when the file doesn't exist
  ! [ -s "${file_path}" ] && return

  tail -n1 "${file_path}"
}
