#!/usr/bin/env bash

function sx::library::tmux::check_requirements() {
  sx::require 'tmux'

  if [ -n "${STY:-}" ]; then
    sx::log::fatal 'This command is not allowed to be run inside an active screen session'
  fi
}

function sx::library::tmux::is_running_session() {
  [ -n "${TMUX:-}" ]
}

function sx::library::tmux::has_session() {
  local -r session_name="${1}"

  if [ -z "${session_name}" ]; then
    sx::log::fatal 'A session name is required as first argument'
  fi

  tmux has-session -t "${session_name}" 2>/dev/null
}

function sx::library::tmux::current_session() {
  if sx::library::tmux::is_running_session; then
    tmux display-message -p '#S' 2>/dev/null
  fi
}

function sx::library::tmux::new_window() {
  local -r session_name="${1}"
  local -r window_name="${2}"
  local -r cmd="${3}"

  if [ -z "${session_name}" ]; then
    sx::log::fatal 'A session name is required as first argument'
  fi

  if [ -z "${window_name}" ]; then
    sx::log::fatal 'A window name is required as second argument'
  fi

  if [ -z "${cmd}" ]; then
    sx::log::fatal 'A command is required as third argument'
  fi

  tmux new-window -t "${session_name}:" -n "${window_name}" "${cmd}"
}

function sx::library::tmux::new_vertical_pane() {
  local -r session_name="${1}"
  local -r cmd="${2}"

  if [ -z "${session_name}" ]; then
    sx::log::fatal 'A session name is required as first argument'
  fi

  if [ -z "${cmd}" ]; then
    sx::log::fatal 'A command is required as second argument'
  fi

  tmux selectp -t "${session_name}:"
  tmux splitw -v "${cmd}"
  tmux select-layout 'tiled'
}

function sx::library::tmux::resize_current_pane_down() {
  local -r cells="${1}"

  if [ -z "${cells}" ]; then
    sx::log::fatal 'A number of cells is required as first argument'
  fi

  tmux resize-pane -D "${cells}"
}

function sx::library::tmux::list_sessions() {
  tmux list-sessions -F '#{session_name}' 2>/dev/null
}

function sx::library::tmux::new_session() {
  local -r session_name="${1}"

  if [ -z "${session_name}" ]; then
    sx::log::fatal 'A session name is required as first argument'
  fi

  if sx::library::tmux::has_session "${session_name}"; then
    sx::log::fatal "There is an existing session named \"${session_name}\""
  elif sx::library::tmux::is_running_session; then
    tmux new-session -d -s "${session_name}"
    tmux switch-client -t "${session_name}"
  else
    tmux new-session -s "${session_name}"
  fi
}

function sx::library::tmux::new_detached_session() {
  local -r session_name="${1}"

  if [ -z "${session_name}" ]; then
    sx::log::fatal 'A session name is required as first argument'
  fi

  if sx::library::tmux::has_session "${session_name}"; then
    sx::log::fatal "There is an existing session named \"${session_name}\""
  else
    tmux new-session -d -s "${session_name}"
  fi
}

function sx::library::tmux::attach_session() {
  local -r session_name="${1}"

  if [ -z "${session_name}" ]; then
    sx::log::fatal 'A session name is required as first argument'
  fi

  if ! sx::library::tmux::has_session "${session_name}"; then
    sx::log::fatal "There is no session named \"${session_name}\""
  elif sx::library::tmux::is_running_session; then
    tmux switch-client -t "${session_name}"
  else
    tmux attach-session -t "${session_name}"
  fi
}

function sx::library::tmux::force_attach_session() {
  local -r session_name="${1}"

  if [ -z "${session_name}" ]; then
    sx::log::fatal 'A session name is required as first argument'
  fi

  if sx::library::tmux::has_session "${session_name}"; then
    sx::library::tmux::attach_session "${session_name}"
  else
    sx::library::tmux::new_session "${session_name}"
  fi
}

function sx::library::tmux::kill_session() {
  local -r session_name="${1}"

  if [ -z "${session_name}" ]; then
    sx::log::fatal 'A session name is required as first argument'
  fi

  if ! sx::library::tmux::has_session "${session_name}"; then
    sx::log::fatal "There is no session named \"${session_name}\""
  else
    tmux kill-session -t "${session_name}" \
      && sx::log::info "Done! Session \"${session_name}\" removed!"
  fi
}
