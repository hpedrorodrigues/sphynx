#!/usr/bin/env bash

readonly brew_directory_prefix='/usr/local/Cellar/sphynx/'
readonly brew_directory_suffix="/bin/${SPHYNX_EXEC_NAME}"
readonly brew_executable="/usr/local/bin/${SPHYNX_EXEC_NAME}"

function sx::self::version() {
  sx::require_supported_os

  if [ "${SPHYNX_EXEC}" == "${brew_executable}" ]; then
    if sx::os::is_linux; then
      local -r pm_description='Linuxbrew'
    else
      local -r pm_description='Homebrew'
    fi

    local -r version="$(
      sx::os::realpath "${SPHYNX_EXEC}" \
        | sed "s#${brew_directory_prefix}##" \
        | sed "s#${brew_directory_suffix}##"
    )"

    echo "${pm_description}: ${version}"

    return 0
  fi

  if sx::os::is_command_available 'git'; then
    local -r remote_url="$(sx::git::remote::url)"

    if [ -n "${remote_url}" ]; then
      echo "Git (Branch): $(sx::git::current_branch)"
      return ${?}
    fi
  fi

  echo 'dev'
}
