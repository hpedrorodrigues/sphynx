#!/usr/bin/env bash

# Simulates a stack using a file to persist data (each line is an item in the stack).

function sx::file_stack::push() {
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

function sx::file_stack::pop() {
  local -r file_path="${1}"

  if [ -z "${file_path}" ]; then
    sx::log::fatal 'Invalid file (empty)!'
  fi

  # return when the file doesn't exist
  ! [ -s "${file_path}" ] && return

  local -r last_line="$(tail -n1 "${file_path}")"

  # remove last line
  echo "${last_line}" \
    | wc -c \
    | xargs -I % truncate "${file_path}" -s -%

  echo "${last_line}"
}
