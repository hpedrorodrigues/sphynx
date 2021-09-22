#!/usr/bin/env bash

function sx::os::is_osx() {
  [ "$(uname)" = 'Darwin' ]
}

function sx::os::is_linux() {
  [ "$(uname)" = 'Linux' ]
}

function sx::os::is_command_available() {
  local -r command="${1:-}"

  if [ -z "${command:-}" ]; then
    sx::log::fatal 'You must provide a command to this function'
  fi

  hash "${command}" 2>/dev/null
}

function sx::os::open() {
  local -r open_commands=(
    'xdg-open'
    'gnome-open'
    'open'
  )

  for open_command in "${open_commands[@]}"; do
    if sx::os::is_command_available "${open_command}"; then
      command "${open_command}" "${*}" &>/dev/null &
      return 0
    fi
  done

  sx::log::fatal "No command-line utility available to use: \"${*}\""
}

function sx::os::browser::open() {
  if [ -n "${BROWSER:-}" ]; then
    exec "${BROWSER}" "${*}" &>/dev/null
  fi

  local -r browser_commands=(
    'x-www-browser'
    'www-browser'
    'gnome-www-browser'
    'sensible-browser'
  )

  for browser_command in "${browser_commands[@]}"; do
    if sx::os::is_command_available "${browser_command}"; then
      command "${browser_command}" "${*}" &>/dev/null &
      return 0
    fi
  done

  sx::os::open "${*}"
}

# References:
# - https://stackoverflow.com/a/60580176/3691240
# - https://github.com/ko1nksm/readlinkf
function sx::os::realpath() {
  local -r filepath="${1}"

  if [ -z "${filepath}" ]; then
    sx::log::fatal 'This function needs a file path as first argument'
  fi

  if ! [ -f "${filepath}" ]; then
    sx::log::fatal 'This function needs a valid file path as first argument'
  fi

  export CDPATH='' # to avoid changing to an unexpected directory

  local max_symlinks='10'
  local target="${filepath}"

  [ -e "${target%/}" ] || target=${1%"${1##*[!/]}"} # trim trailing slashes

  [ -d "${target:-/}" ] && target="${target}/"

  cd -P . 2>/dev/null || return 1

  while [ "${max_symlinks}" -ge 0 ] \
    && max_symlinks=$((max_symlinks - 1)); do
    if [ ! "${target}" = "${target%/*}" ]; then
      case ${target} in
        /*) cd -P "${target%/*}/" 2>/dev/null || break ;;
        *) cd -P "./${target%/*}" 2>/dev/null || break ;;
      esac
      target=${target##*/}
    fi

    if [ ! -L "${target}" ]; then
      target="${PWD%/}${target:+/}${target}"
      printf '%s\n' "${target:-/}"
      return 0
    fi

    # `ls -dl` format: "%s %u %s %s %u %s %s -> %s\n",
    #   <file mode>, <number of links>, <owner name>, <group name>,
    #   <size>, <date and time>, <pathname of link>, <contents of link>
    # https://pubs.opengroup.org/onlinepubs/9699919799/utilities/ls.html
    link=$(ls -dl -- "${target}" 2>/dev/null) || break
    target=${link#*" ${target} -> "}
  done

  return 1
}
