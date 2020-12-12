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

  tmux new-window -t "${session_name}:" -n "${window_name}" "${cmd}"
}

function sx::library::tmux::new_vertical_pane() {
  local -r session_name="${1}"
  local -r cmd="${2}"

  tmux selectp -t "${session_name}:"
  tmux splitw -v "${cmd}"
  tmux select-layout tiled
}

function sx::library::tmux::list_sessions() {
  local -r all_sessions="${1:-false}"

  if ${all_sessions} || ! sx::library::tmux::is_running_session; then
    local -r sessions="$(tmux list-sessions -F '#{session_name}' 2>/dev/null)"
    local -r current_session="$(sx::library::tmux::current_session)"
    # shellcheck disable=SC2068  # Double quote array expansions
    for session in ${sessions[@]}; do
      if [ "${current_session}" = "${session}" ]; then
        echo "${SX_FZF_CURRENT_BGCOLOR}${SX_FZF_CURRENT_FGCOLOR}${session}${SX_FZF_CURRENT_RESETCOLOR}"
      else
        echo "${session}"
      fi
    done
  else
    tmux list-sessions -F '#{session_name}' 2>/dev/null \
      | grep -v -E "^$(sx::library::tmux::current_session)$"
  fi
}

function sx::library::tmux::new_session() {
  local -r session_name="${1}"

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

  if sx::library::tmux::has_session "${session_name}"; then
    sx::log::fatal "There is an existing session named \"${session_name}\""
  else
    tmux new-session -d -s "${session_name}"
  fi
}

function sx::library::tmux::attach_session() {
  local -r session_name="${1}"

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

  if sx::library::tmux::has_session "${session_name}"; then
    sx::library::tmux::attach_session "${session_name}"
  else
    sx::library::tmux::new_session "${session_name}"
  fi
}

function sx::library::tmux::kill_session() {
  local -r session_name="${1}"

  if ! sx::library::tmux::has_session "${session_name}"; then
    sx::log::fatal "There is no session named \"${session_name}\""
  else
    tmux kill-session -t "${session_name}" \
      && sx::log::info "Done! Session \"${session_name}\" removed!"
  fi
}
