#!/usr/bin/env bash

function sx::security::hash::md5() {
  sx::security::check_requirements

  if [ "${#}" -gt '0' ]; then
    # shellcheck disable=SC2068  # Double quote array expansions
    for filename in ${@}; do
      if [ -n "${filename}" ] && ! [ -f "${filename}" ]; then
        sx::log::fatal 'No such file'
      fi

      if [ -n "${filename}" ]; then
        if sx::os::is_command_available 'openssl'; then
          openssl md5 "${filename}" | awk '{ print $2 }'
        elif sx::os::is_command_available 'md5sum'; then
          md5sum "${filename}" | awk '{ print $1 }'
        elif sx::os::is_command_available 'md5'; then
          md5 "${filename}" | awk '{ print $4 }'
        else
          sx::log::fatal 'No md5 command-line utility available'
        fi
      fi
    done
  else
    if sx::os::is_command_available 'openssl'; then
      cat | openssl md5
    elif sx::os::is_command_available 'md5sum'; then
      cat | md5sum | awk '{ print $1 }'
    elif sx::os::is_command_available 'md5'; then
      cat | md5
    else
      sx::log::fatal 'No md5 command-line utility available'
    fi
  fi
}

function sx::security::hash::sha1() {
  sx::security::check_requirements

  if [ "${#}" -gt '0' ]; then
    # shellcheck disable=SC2068  # Double quote array expansions
    for filename in ${@}; do
      if [ -n "${filename}" ] && ! [ -f "${filename}" ]; then
        sx::log::fatal 'No such file'
      fi

      if [ -n "${filename}" ]; then
        if sx::os::is_command_available 'openssl'; then
          openssl sha1 "${filename}" | awk '{ print $2 }'
        elif sx::os::is_command_available 'sha1sum'; then
          sha1sum "${filename}" | awk '{ print $1 }'
        elif sx::os::is_command_available 'shasum'; then
          shasum "${filename}" | awk '{ print $1 }'
        else
          sx::log::fatal 'No sha1 command-line utility available'
        fi
      fi
    done
  else
    if sx::os::is_command_available 'openssl'; then
      cat | openssl sha1
    elif sx::os::is_command_available 'sha1sum'; then
      cat | sha1sum | awk '{ print $1 }'
    elif sx::os::is_command_available 'shasum'; then
      cat | shasum | awk '{ print $1 }'
    else
      sx::log::fatal 'No sha1 command-line utility available'
    fi
  fi
}

function sx::security::hash::sha256() {
  sx::security::check_requirements

  if [ "${#}" -gt '0' ]; then
    # shellcheck disable=SC2068  # Double quote array expansions
    for filename in ${@}; do
      if [ -n "${filename}" ] && ! [ -f "${filename}" ]; then
        sx::log::fatal 'No such file'
      fi

      if [ -n "${filename}" ]; then
        if sx::os::is_command_available 'openssl'; then
          openssl sha256 "${filename}" | awk '{ print $2 }'
        elif sx::os::is_command_available 'sha256sum'; then
          sha256sum "${filename}" | awk '{ print $1 }'
        elif sx::os::is_command_available 'shasum'; then
          shasum --algorithm 256 "${filename}" | awk '{ print $1 }'
        else
          sx::log::fatal 'No sha256 command-line utility available'
        fi
      fi
    done
  else
    if sx::os::is_command_available 'openssl'; then
      cat | openssl sha256
    elif sx::os::is_command_available 'sha256sum'; then
      cat | sha256sum | awk '{ print $1 }'
    elif sx::os::is_command_available 'shasum'; then
      cat | shasum --algorithm 256 | awk '{ print $1 }'
    else
      sx::log::fatal 'No sha256 command-line utility available'
    fi
  fi
}
