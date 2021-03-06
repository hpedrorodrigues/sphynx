#!/usr/bin/env bash

function sx::library::screen::check_requirements() {
  sx::require_supported_os
  sx::require 'screen'

  if [ -n "${TMUX:-}" ]; then
    sx::log::fatal 'This command is not allowed to be run inside an active tmux session'
  fi
}

function sx::library::screen::is_running_session() {
  [ -n "${STY:-}" ]
}

function sx::library::screen::has_session() {
  local -r session_name="${1}"

  if [ -z "${session_name}" ]; then
    sx::log::fatal 'A session name is required as first argument'
  fi

  screen -S "${session_name}" -Q select . &>/dev/null
}

function sx::library::screen::current_session() {
  if sx::library::screen::is_running_session; then
    # shellcheck disable=SC2001  # See if you can use ${variable//search/replace} instead
    echo "${STY:-}" | sed 's/[0-9]*\.//'
  fi
}

function sx::library::screen::list_sessions() {
  screen -ls \
    | grep -E '[0-9]\.[a-zA-Z]*' \
    | awk '{ print $1 }' \
    | sed 's/[0-9]*\.//'
}

function sx::library::screen::new_session() {
  local -r session_name="${1}"

  if [ -z "${session_name}" ]; then
    sx::log::fatal 'A session name is required as first argument'
  fi

  if sx::library::screen::has_session "${session_name}"; then
    sx::log::fatal "There is an existing session named \"${session_name}\""
  elif sx::library::screen::is_running_session; then
    local -r current_session="$(sx::library::screen::current_session)"

    screen -S "${session_name}"
    screen -d "${current_session}"
  else
    screen -S "${session_name}"
  fi
}

function sx::library::screen::attach_session() {
  local -r session_name="${1}"

  if [ -z "${session_name}" ]; then
    sx::log::fatal 'A session name is required as first argument'
  fi

  if ! sx::library::screen::has_session "${session_name}"; then
    sx::log::fatal "There is no session named \"${session_name}\""
  elif sx::library::screen::is_running_session; then
    local -r current_session="$(sx::library::screen::current_session)"

    screen -r "${session_name}"
    screen -d "${current_session}"
  else
    screen -r "${session_name}"
  fi
}

function sx::library::screen::force_attach_session() {
  local -r session_name="${1}"

  if [ -z "${session_name}" ]; then
    sx::log::fatal 'A session name is required as first argument'
  fi

  if sx::library::screen::has_session "${session_name}"; then
    sx::library::screen::attach_session "${session_name}"
  else
    sx::library::screen::new_session "${session_name}"
  fi
}

function sx::library::screen::kill_session() {
  local -r session_name="${1}"

  if [ -z "${session_name}" ]; then
    sx::log::fatal 'A session name is required as first argument'
  fi

  if ! sx::library::screen::has_session "${session_name}"; then
    sx::log::fatal "There is no session named \"${session_name}\""
  else
    screen -X -S "${session_name}" quit \
      && sx::log::info "Done! Session \"${session_name}\" removed!"
  fi
}
