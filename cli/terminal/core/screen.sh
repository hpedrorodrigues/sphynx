#!/usr/bin/env bash
# shellcheck disable=SC2128
# shellcheck disable=SC2178
# Reference: https://github.com/koalaman/shellcheck/wiki/SC2128#bugs

export SX_SCREEN_SESSION_NAME_PREFIX="${SX_SCREEN_SESSION_NAME_PREFIX:-sphynx}"

function sx::terminal::screen::ls() {
  sx::library::screen::check_requirements

  local -r sessions="$(sx::library::screen::list_sessions)"

  if [ -z "${sessions}" ]; then
    sx::log::fatal 'No sessions found'
  elif sx::library::screen::is_running_session; then
    local -r current_session="$(sx::library::screen::current_session)"
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
  sx::library::screen::check_requirements

  local -r session_name="${1}"

  if [ -n "${session_name}" ]; then
    sx::library::screen::new_session "${session_name}"
  else
    local -r counter="$(
      sx::library::screen::list_sessions \
        | grep -c -E "^${SX_SCREEN_SESSION_NAME_PREFIX}"
    )"

    sx::library::screen::new_session "${SX_SCREEN_SESSION_NAME_PREFIX}${counter}"
  fi
}

function sx::terminal::screen::attach() {
  sx::library::screen::check_requirements

  local -r session_name="${1}"

  if [ -n "${session_name}" ]; then
    sx::library::screen::attach_session "${session_name}"
  elif sx::os::is_command_available 'fzf'; then
    local -r options="$(sx::library::screen::list_sessions)"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No sessions found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf ${SX_FZF_ARGS})"

    [ -n "${selected}" ] \
      && sx::library::screen::attach_session "${selected}"
  else
    export PS3=$'\n''Please, choose the session: '$'\n'

    local options
    readarray -t options < <(sx::library::screen::list_sessions)

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No sessions found'
    fi

    select selected in "${options[@]}"; do
      sx::library::screen::attach_session "${selected}"
      break
    done
  fi
}

function sx::terminal::screen::force_attach() {
  sx::library::screen::check_requirements

  local -r session_name="${1}"

  if [ -n "${session_name}" ]; then
    sx::library::screen::force_attach_session "${session_name}"
  else
    sx::terminal::screen::attach "${session_name}"
  fi
}

function sx::terminal::screen::kill() {
  sx::library::screen::check_requirements

  local -r session_name="${1}"

  if [ -n "${session_name}" ]; then
    sx::library::screen::kill_session "${session_name}"
  elif sx::os::is_command_available 'fzf'; then
    local -r options="$(sx::library::screen::list_sessions)"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No sessions found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf ${SX_FZF_ARGS})"

    [ -n "${selected}" ] \
      && sx::library::screen::kill_session "${selected}"
  else
    export PS3=$'\n''Please, choose the session: '$'\n'

    local options
    readarray -t options < <(sx::library::screen::list_sessions)

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No sessions found'
    fi

    select selected in "${options[@]}"; do
      sx::library::screen::kill_session "${selected}"
      break
    done
  fi
}

function sx::terminal::screen::kill_all() {
  sx::library::screen::check_requirements

  local -r sessions="$(sx::library::screen::list_sessions)"

  if [ -z "${sessions}" ]; then
    sx::log::fatal 'No sessions found'
  else
    local -r current_session="$(sx::library::screen::current_session)"
    # shellcheck disable=SC2068  # Double quote array expansions
    for session_name in ${sessions[@]}; do
      if [ "${current_session}" = "${session_name}" ]; then
        continue
      else
        sx::library::screen::kill_session "${session_name}"
      fi
    done

    [ -n "${current_session}" ] \
      && sx::library::screen::kill_session "${current_session}"
  fi
}
