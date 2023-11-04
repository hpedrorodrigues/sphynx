#!/usr/bin/env bash

function sx::macos::airport() {
  if sx::os::is_macos; then
    '/System/Library/PrivateFrameworks/Apple80211.framework/Versions/A/Resources/airport' "${@}"
  else
    sx::log::fatal 'The airport command is not available in your OS'
  fi
}

# References:
# - http://blog.macromates.com/2006/keychain-access-from-shell
function sx::macos::keychain_pass() {
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

function sx::macos::default_browser_application() {
  if sx::os::is_macos; then
    local -r browser_id="$(
      defaults read com.apple.LaunchServices/com.apple.launchservices.secure LSHandlers \
        | grep 'LSHandlerURLScheme = https;' -B1 \
        | grep 'LSHandlerRoleAll' \
        | cut -d '=' -f '2' \
        | sed 's/["|;]//g' \
        | tr -d ' ' 2>/dev/null
    )"

    if [ -n "${browser_id}" ]; then
      if [ "${browser_id}" == 'com.google.chrome' ]; then
        echo 'Google Chrome'
      elif [ "${browser_id}" == 'com.apple.safari' ]; then
        echo 'Safari'
      elif [ "${browser_id}" == 'org.mozilla.firefox' ]; then
        echo 'Firefox'
      elif [ "${browser_id}" == 'org.mozilla.firefoxdeveloperedition' ]; then
        echo 'Firefox Developer Edition'
      elif [ "${browser_id}" == 'com.vivaldi.vivaldi' ]; then
        echo 'Vivaldi'
      fi
    fi
  fi
}
