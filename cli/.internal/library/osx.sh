#!/usr/bin/env bash

function sx::osx::airport() {
  if sx::os::is_osx; then
    '/System/Library/PrivateFrameworks/Apple80211.framework/Versions/A/Resources/airport' "${@}"
  else
    sx::log::fatal 'The airport command is not available in your OS'
  fi
}

function sx::osx::is_catalina_or_newer() {
  local -r major_version="$(sw_vers -productVersion | sed 's/\.[0-9]*\.[0-9]*//')"

  [ "${major_version}" -gt 10 ] || [ "${major_version}" = 10 ]
}

# Reference: http://blog.macromates.com/2006/keychain-access-from-shell/
function sx::osx::keychain_pass() {
  local -r account="${1:-}"

  if [ -z "${account:-}" ]; then
    sx::log::fatal 'This function needs an account as first argument'
  fi

  local -r raw_password="$(security find-generic-password -ga "${account}" 2>&1 >/dev/null)"

  if [[ ${raw_password} =~ 'could' ]]; then
    sx::log::fatal "Cannot find account \"${account}\""
  fi

  # shellcheck disable=SC2001  # See if you can use ${variable//search/replace} instead
  local -r password="$(echo "${raw_password}" | sed -e "s/^.*\"\(.*\)\".*$/\1/")"

  if [ -z "${password}" ]; then
    sx::log::fatal 'Could not get password. Did you enter your Keychain credentials?'
  fi

  echo "${password}"
}
