#!/usr/bin/env bash
# shellcheck disable=SC2128
# shellcheck disable=SC2178
# Reference: https://github.com/koalaman/shellcheck/wiki/SC2128#bugs

export SX_TMUX_SESSION_NAME_PREFIX="${SX_TMUX_SESSION_NAME_PREFIX:-sphynx}"

# Validation functions

function sx::terminal::tmux::check_requirements() {
  sx::require 'tmux'
}

# Helper functions

function sx::terminal::tmux::is_running_session() {
  [ -n "${TMUX:-}" ]
}

function sx::terminal::tmux_command::has_session() {
  local -r session_name="${1}"

  tmux has-session -t "${session_name}" 2>/dev/null
}

function sx::terminal::tmux_command::current_session() {
  if sx::terminal::tmux::is_running_session; then
    tmux display-message -p '#S' 2>/dev/null
  fi
}

function sx::terminal::tmux_command::list_sessions() {
  local -r all_sessions="${1:-false}"

  if ${all_sessions} || ! sx::terminal::tmux::is_running_session; then
    local -r sessions="$(tmux list-sessions -F '#{session_name}' 2>/dev/null)"
    local -r current_session="$(sx::terminal::tmux_command::current_session)"
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
      | grep -v -E "^$(sx::terminal::tmux_command::current_session)$"
  fi
}

function sx::terminal::tmux_command::new_session() {
  local -r session_name="${1}"

  if sx::terminal::tmux_command::has_session "${session_name}"; then
    sx::log::fatal "There is an existing session named \"${session_name}\""
  elif sx::terminal::tmux::is_running_session; then
    tmux new-session -d -s "${session_name}"
    tmux switch-client -t "${session_name}"
  else
    tmux new-session -s "${session_name}"
  fi
}

function sx::terminal::tmux_command::attach_session() {
  local -r session_name="${1}"

  if ! sx::terminal::tmux_command::has_session "${session_name}"; then
    sx::log::fatal "There is no session named \"${session_name}\""
  elif sx::terminal::tmux::is_running_session; then
    tmux switch-client -t "${session_name}"
  else
    tmux attach-session -t "${session_name}"
  fi
}

function sx::terminal::tmux_command::force_attach_session() {
  local -r session_name="${1}"

  if sx::terminal::tmux_command::has_session "${session_name}"; then
    sx::terminal::tmux_command::attach_session "${session_name}"
  else
    sx::terminal::tmux_command::new_session "${session_name}"
  fi
}

function sx::terminal::tmux_command::kill_session() {
  local -r session_name="${1}"

  if ! sx::terminal::tmux_command::has_session "${session_name}"; then
    sx::log::fatal "There is no session named \"${session_name}\""
  else
    tmux kill-session -t "${session_name}" \
      && sx::log::info "Done! Session \"${session_name}\" removed!"
  fi
}

# Command functions

function sx::terminal::tmux::colors() {
  for i in {0..255}; do
    printf "\x1b[38;5;${i}mcolour%-5i\x1b[0m" "${i}"
    if ! (((i + 1) % 8)); then
      echo
    fi
  done
}

function sx::terminal::tmux::ls() {
  sx::terminal::tmux::check_requirements

  local -r sessions="$(sx::terminal::tmux_command::list_sessions true)"

  if [ -z "${sessions}" ]; then
    sx::log::info 'No sessions available'
  elif sx::terminal::tmux::is_running_session; then
    local -r current_session="$(sx::terminal::tmux_command::current_session)"
    # shellcheck disable=SC2068  # Double quote array expansions
    for session in ${sessions[@]}; do
      if [ "${current_session}" = "${session}" ]; then
        echo "${SX_FZF_CURRENT_BGCOLOR}${SX_FZF_CURRENT_FGCOLOR}${session}${SX_FZF_CURRENT_RESETCOLOR}"
      else
        echo "${session}"
      fi
    done
  else
    sx::log::info "${sessions}"
  fi
}

function sx::terminal::tmux::new() {
  sx::terminal::tmux::check_requirements

  local -r session_name="${1}"

  if [ -n "${session_name}" ]; then
    sx::terminal::tmux_command::new_session "${session_name}"
  else
    local -r counter="$(sx::terminal::tmux_command::list_sessions true \
      | grep -c -E "^${SX_TMUX_SESSION_NAME_PREFIX}")"

    sx::terminal::tmux_command::new_session "${SX_TMUX_SESSION_NAME_PREFIX}${counter}"
  fi
}

function sx::terminal::tmux::attach() {
  sx::terminal::tmux::check_requirements

  local -r session_name="${1}"

  if [ -n "${session_name}" ]; then
    sx::terminal::tmux_command::attach_session "${session_name}"
  elif sx::os::is_command_available 'fzf'; then
    local -r options="$(sx::terminal::tmux_command::list_sessions)"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No sessions found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf ${SX_FZF_ARGS})"

    [ -n "${selected}" ] \
      && sx::terminal::tmux_command::attach_session "${selected}"
  else
    export PS3=$'\n''Please, choose the session: '$'\n'

    local options
    mapfile -t options < <(sx::terminal::tmux_command::list_sessions)

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No sessions found'
    fi

    select selected in "${options[@]}"; do
      sx::terminal::tmux_command::attach_session "${selected}"
      break
    done
  fi
}

function sx::terminal::tmux::force_attach() {
  sx::terminal::tmux::check_requirements

  local -r session_name="${1}"

  if [ -n "${session_name}" ]; then
    sx::terminal::tmux_command::force_attach_session "${session_name}"
  else
    sx::terminal::tmux::attach "${session_name}"
  fi
}

function sx::terminal::tmux::kill() {
  sx::terminal::tmux::check_requirements

  local -r session_name="${1}"

  if [ -n "${session_name}" ]; then
    sx::terminal::tmux_command::kill_session "${session_name}"
  elif sx::os::is_command_available 'fzf'; then
    local -r options="$(sx::terminal::tmux_command::list_sessions true)"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No sessions found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf ${SX_FZF_ARGS})"

    [ -n "${selected}" ] \
      && sx::terminal::tmux_command::kill_session "${selected}"
  else
    export PS3=$'\n''Please, choose the session: '$'\n'

    local options
    mapfile -t options < <(sx::terminal::tmux_command::list_sessions true)

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No sessions found'
    fi

    select selected in "${options[@]}"; do
      sx::terminal::tmux_command::kill_session "${selected}"
      break
    done
  fi
}

function sx::terminal::tmux::kill_all() {
  sx::terminal::tmux::check_requirements

  local -r sessions="$(sx::terminal::tmux_command::list_sessions)"

  if [ -z "${sessions}" ] && ! sx::terminal::tmux::is_running_session; then
    sx::log::info 'No sessions available'
  else
    # shellcheck disable=SC2068  # Double quote array expansions
    for session_name in ${sessions[@]}; do
      sx::terminal::tmux_command::kill_session "${session_name}"
    done

    local -r current_session="$(sx::terminal::tmux_command::current_session)"

    [ -n "${current_session}" ] \
      && sx::terminal::tmux_command::kill_session "${current_session}"
  fi
}
