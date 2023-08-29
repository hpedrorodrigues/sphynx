#!/usr/bin/env bash

export SX_TMUX_SESSION_NAME="${SX_TMUX_SESSION_NAME:-sphynx-tmux}"

function sx::library::tmux::check_requirements() {
  sx::require_supported_os
  sx::require 'tmux'

  if [ -n "${STY:-}" ]; then
    sx::log::fatal 'This command is not allowed to be run inside an active screen session'
  fi
}

function sx::library::tmux::is_running_session() {
  [ -n "${TMUX:-}" ] && [ "${TERM_PROGRAM:-}" = 'tmux' ]
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

function sx::library::tmux::new_splitted_window() {
  local -r window_title="${1}"
  local -r fst_pane_cmd="${2}"
  local -r snd_pane_cmd="${3}"

  if [ -z "${window_title}" ]; then
    sx::log::fatal 'A window title is required as first argument'
  fi

  if [ -z "${fst_pane_cmd}" ]; then
    sx::log::fatal 'A command to the first pane is required as second argument'
  fi

  if [ -z "${snd_pane_cmd}" ]; then
    sx::log::fatal 'A command to the second pane is required as third argument'
  fi

  if sx::library::tmux::is_running_session; then
    local -r session_name="$(sx::library::tmux::current_session)"
  elif sx::library::tmux::has_session "${SX_TMUX_SESSION_NAME}"; then
    local -r session_name="${SX_TMUX_SESSION_NAME}"
  else
    local -r session_name="${SX_TMUX_SESSION_NAME}"
    sx::library::tmux::new_detached_session "${session_name}"
  fi

  sx::library::tmux::new_window \
    "${session_name}" \
    "${window_title}" \
    "${fst_pane_cmd}"

  sx::library::tmux::new_vertical_pane \
    "${session_name}" \
    "${snd_pane_cmd}"

  sx::library::tmux::resize_current_pane_down '10'

  sx::library::tmux::force_attach_session "${session_name}"
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
