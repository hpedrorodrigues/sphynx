#!/usr/bin/env bash
# shellcheck disable=SC2128
# shellcheck disable=SC2178
# Reference: https://github.com/koalaman/shellcheck/wiki/SC2128#bugs

export SX_SCREEN_SESSION_NAME_PREFIX="${SX_SCREEN_SESSION_NAME_PREFIX:-sphynx}"

# Validation functions

function sx::terminal::screen::check_requirements() {
  sx::require 'screen'

  if [ -n "${TMUX:-}" ]; then
    sx::log::fatal 'This command is not allowed to be run inside an active tmux session'
  fi
}

function sx::terminal::screen::check_not_running_session() {
  if sx::terminal::screen::is_running_session; then
    sx::log::fatal "It'is not possible to run this command inside a screen session"
  fi
}

# Helper functions

function sx::terminal::screen::is_running_session() {
  [ -n "${STY:-}" ]
}

function sx::terminal::screen_command::has_session() {
  local -r session_name="${1}"

  screen -S "${session_name}" -Q select . &>/dev/null
}

function sx::terminal::screen_command::current_session() {
  if sx::terminal::screen::is_running_session; then
    echo "${STY:-}"
  fi
}

function sx::terminal::screen_command::list_sessions() {
  screen -ls \
    | grep -E '[0-9]\.[a-zA-Z]*' \
    | awk '{ print $1 }' \
    | sed 's/[0-9]*\.//'
}

function sx::terminal::screen_command::new_session() {
  local -r session_name="${1}"

  if sx::terminal::screen_command::has_session "${session_name}"; then
    sx::log::fatal "There is an existing session named \"${session_name}\""
  else
    screen -S "${session_name}"
  fi
}

function sx::terminal::screen_command::attach_session() {
  local -r session_name="${1}"

  if ! sx::terminal::screen_command::has_session "${session_name}"; then
    sx::log::fatal "There is no session named \"${session_name}\""
  else
    screen -r "${session_name}"
  fi
}

function sx::terminal::screen_command::force_attach_session() {
  local -r session_name="${1}"

  if sx::terminal::screen_command::has_session "${session_name}"; then
    sx::terminal::screen_command::attach_session "${session_name}"
  else
    sx::terminal::screen_command::new_session "${session_name}"
  fi
}

function sx::terminal::screen_command::kill_session() {
  local -r session_name="${1}"

  if ! sx::terminal::screen_command::has_session "${session_name}"; then
    sx::log::fatal "There is no session named \"${session_name}\""
  else
    screen -X -S "${session_name}" quit \
      && sx::log::info "Done! Session \"${session_name}\" removed!"
  fi
}

# Command functions

function sx::terminal::screen::ls() {
  sx::terminal::screen::check_requirements

  local -r sessions="$(sx::terminal::screen_command::list_sessions)"

  if [ -z "${sessions}" ]; then
    sx::log::info 'No sessions available'
  elif sx::terminal::screen::is_running_session; then
    local -r current_session="$(sx::terminal::screen_command::current_session \
      | sed 's/[0-9]*\.//')"
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

function sx::terminal::screen::new() {
  sx::terminal::screen::check_requirements
  sx::terminal::screen::check_not_running_session

  local -r session_name="${1}"

  if [ -n "${session_name}" ]; then
    sx::terminal::screen_command::new_session "${session_name}"
  else
    local -r counter="$(sx::terminal::screen_command::list_sessions \
      | grep -c -E "^${SX_SCREEN_SESSION_NAME_PREFIX}")"

    sx::terminal::screen_command::new_session "${SX_SCREEN_SESSION_NAME_PREFIX}${counter}"
  fi
}

function sx::terminal::screen::attach() {
  sx::terminal::screen::check_requirements
  sx::terminal::screen::check_not_running_session

  local -r session_name="${1}"

  if [ -n "${session_name}" ]; then
    sx::terminal::screen_command::attach_session "${session_name}"
  elif sx::os::is_command_available 'fzf'; then
    local -r options="$(sx::terminal::screen_command::list_sessions)"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No sessions found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf ${SX_FZF_ARGS})"

    [ -n "${selected}" ] \
      && sx::terminal::screen_command::attach_session "${selected}"
  else
    export PS3=$'\n''Please, choose the session: '$'\n'

    local options
    mapfile -t options < <(sx::terminal::screen_command::list_sessions)

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No sessions found'
    fi

    select selected in "${options[@]}"; do
      sx::terminal::screen_command::attach_session "${selected}"
      break
    done
  fi
}

function sx::terminal::screen::force_attach() {
  sx::terminal::screen::check_requirements
  sx::terminal::screen::check_not_running_session

  local -r session_name="${1}"

  if [ -n "${session_name}" ]; then
    sx::terminal::screen_command::force_attach_session "${session_name}"
  else
    sx::terminal::screen::attach "${session_name}"
  fi
}

function sx::terminal::screen::kill() {
  sx::terminal::screen::check_requirements
  sx::terminal::screen::check_not_running_session

  local -r session_name="${1}"

  if [ -n "${session_name}" ]; then
    sx::terminal::screen_command::kill_session "${session_name}"
  elif sx::os::is_command_available 'fzf'; then
    local -r options="$(sx::terminal::screen_command::list_sessions)"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No sessions found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf ${SX_FZF_ARGS})"

    [ -n "${selected}" ] \
      && sx::terminal::screen_command::kill_session "${selected}"
  else
    export PS3=$'\n''Please, choose the session: '$'\n'

    local options
    mapfile -t options < <(sx::terminal::screen_command::list_sessions)

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No sessions found'
    fi

    select selected in "${options[@]}"; do
      sx::terminal::screen_command::kill_session "${selected}"
      break
    done
  fi
}

function sx::terminal::screen::kill_all() {
  sx::terminal::screen::check_requirements
  sx::terminal::screen::check_not_running_session

  local -r sessions="$(sx::terminal::screen_command::list_sessions)"

  if [ -z "${sessions}" ]; then
    sx::log::info 'No sessions available'
  else
    # shellcheck disable=SC2068  # Double quote array expansions
    for session_name in ${sessions[@]}; do
      sx::terminal::screen_command::kill_session "${session_name}"
    done
  fi
}
