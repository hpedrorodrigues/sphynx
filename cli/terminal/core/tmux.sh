#!/usr/bin/env bash
# shellcheck disable=SC2128
# shellcheck disable=SC2178
# References:
# - https://github.com/koalaman/shellcheck/wiki/SC2128#bugs

export SX_TMUX_SESSION_NAME_PREFIX="${SX_TMUX_SESSION_NAME_PREFIX:-sphynx}"

function sx::terminal::tmux::colors() {
  for i in {0..255}; do
    printf "\x1b[38;5;${i}mcolour%-5i\x1b[0m" "${i}"
    if ! (((i + 1) % 8)); then
      echo
    fi
  done
}

function sx::terminal::tmux::ls() {
  sx::library::tmux::check_requirements

  local -r sessions="$(sx::library::tmux::list_sessions)"

  if [ -z "${sessions}" ]; then
    sx::log::fatal 'No sessions found'
  elif sx::library::tmux::is_running_session; then
    local -r current_session="$(sx::library::tmux::current_session)"
    # shellcheck disable=SC2068  # Double quote array expansions
    for session in ${sessions[@]}; do
      if [ "${current_session}" = "${session}" ]; then
        sx::color::current_item::echo "${session}"
      else
        echo "${session}"
      fi
    done
  else
    sx::log::info "${sessions}"
  fi
}

function sx::terminal::tmux::new() {
  sx::library::tmux::check_requirements

  local -r session_name="${1}"

  if [ -n "${session_name}" ]; then
    sx::library::tmux::new_session "${session_name}"
  else
    local -r counter="$(
      sx::library::tmux::list_sessions \
        | grep -c -E "^${SX_TMUX_SESSION_NAME_PREFIX}"
    )"

    sx::library::tmux::new_session "${SX_TMUX_SESSION_NAME_PREFIX}${counter}"
  fi
}

function sx::terminal::tmux::attach() {
  sx::library::tmux::check_requirements

  local -r session_name="${1}"

  if [ -n "${session_name}" ]; then
    sx::library::tmux::attach_session "${session_name}"
  elif sx::os::is_command_available 'fzf'; then
    local -r options="$(
      sx::library::tmux::list_sessions \
        | grep -v -E "^$(sx::library::tmux::current_session)$"
    )"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No sessions found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf ${SX_FZF_ARGS})"

    [ -n "${selected}" ] \
      && sx::library::tmux::attach_session "${selected}"
  else
    export PS3=$'\n''Please, choose the session: '$'\n'

    local options
    readarray -t options < <(
      sx::library::tmux::list_sessions \
        | grep -v -E "^$(sx::library::tmux::current_session)$"
    )

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No sessions found'
    fi

    select selected in "${options[@]}"; do
      sx::library::tmux::attach_session "${selected}"
      break
    done
  fi
}

function sx::terminal::tmux::force_attach() {
  sx::library::tmux::check_requirements

  local -r session_name="${1}"

  if [ -n "${session_name}" ]; then
    sx::library::tmux::force_attach_session "${session_name}"
  else
    sx::terminal::tmux::attach "${session_name}"
  fi
}

function sx::terminal::tmux::kill() {
  sx::library::tmux::check_requirements

  local -r session_name="${1}"

  if [ -n "${session_name}" ]; then
    sx::library::tmux::kill_session "${session_name}"
  elif sx::os::is_command_available 'fzf'; then
    local -r options="$(sx::terminal::tmux::ls 2>/dev/null)"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No sessions found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf ${SX_FZF_ARGS})"

    [ -n "${selected}" ] \
      && sx::library::tmux::kill_session "${selected}"
  else
    export PS3=$'\n''Please, choose the session: '$'\n'

    local options
    readarray -t options < <(sx::terminal::tmux::ls 2>/dev/null)

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No sessions found'
    fi

    select selected in "${options[@]}"; do
      sx::library::tmux::kill_session "${selected}"
      break
    done
  fi
}

function sx::terminal::tmux::kill_all() {
  sx::library::tmux::check_requirements

  local -r sessions="$(sx::library::tmux::list_sessions)"

  if [ -z "${sessions}" ]; then
    sx::log::fatal 'No sessions found'
  else
    local -r current_session="$(sx::library::tmux::current_session)"

    # shellcheck disable=SC2068  # Double quote array expansions
    for session_name in ${sessions[@]}; do
      if [ "${current_session}" = "${session_name}" ]; then
        continue
      else
        sx::library::tmux::kill_session "${session_name}"
      fi
    done

    [ -n "${current_session}" ] \
      && sx::library::tmux::kill_session "${current_session}"
  fi
}
