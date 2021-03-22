#!/usr/bin/env bash

readonly brew_directory_prefix='/usr/local/Cellar/sphynx/'
readonly brew_directory_suffix="/bin/${SPHYNX_EXEC_NAME}"
readonly brew_executable="/usr/local/bin/${SPHYNX_EXEC_NAME}"

function sx::self::version() {
  sx::require_supported_os

  if [ "${SPHYNX_EXEC}" == "${brew_executable}" ]; then
    local -r symlink_target="$(
      find "${SPHYNX_EXEC}" -type l -ls \
        | awk -F '->' '{ print $2 }'
    )"

    (
      cd "$(dirname "${SPHYNX_EXEC}")" || return 1
      cd "$(dirname "${symlink_target}")" || return 1

      if sx::os::is_linux; then
        local -r pm_description='Linuxbrew'
      else
        local -r pm_description='Homebrew'
      fi

      local -r real_sphynx_exec="${PWD}/${SPHYNX_EXEC_NAME}"
      local -r version="$(
        echo "${real_sphynx_exec}" \
          | sed "s#${brew_directory_prefix}##" \
          | sed "s#${brew_directory_suffix}##"
      )"

      echo "${pm_description}: ${version}"
    )

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
