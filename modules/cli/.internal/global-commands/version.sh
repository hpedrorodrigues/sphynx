#!/usr/bin/env bash

function sx::self::version() {
  sx::log::info "Runtime:\n  $(sx::python --version)"
  sx::log::info "Sphynx:\n  $(sx::self::version::internal)"
}

function sx::self::version::internal() {
  sx::require_supported_os

  if sx::os::is_linux; then
    local -r package_manager_name='Linuxbrew'
    local -r brew_directory_prefix='/home/linuxbrew/.linuxbrew/Cellar/sphynx/'
    local -r brew_directory_suffix="/bin/${SPHYNX_EXEC_NAME}"
    local -r brew_executable="/home/linuxbrew/.linuxbrew/bin/${SPHYNX_EXEC_NAME}"
  else
    local -r package_manager_name='Homebrew'
    local -r brew_directory_prefix='/usr/local/Cellar/sphynx/'
    local -r brew_directory_suffix="/bin/${SPHYNX_EXEC_NAME}"
    local -r brew_executable="/usr/local/bin/${SPHYNX_EXEC_NAME}"
  fi

  if [ "${SPHYNX_EXEC}" == "${brew_executable}" ]; then
    local -r version="$(
      sx::os::realpath "${SPHYNX_EXEC}" \
        | sed "s#${brew_directory_prefix}##" \
        | sed "s#${brew_directory_suffix}##"
    )"

    echo "${package_manager_name}: ${version}"

    return 0
  fi

  if sx::os::is_command_available 'git'; then
    local -r remote_url="$(sx::git::remote::url)"

    if [ -n "${remote_url}" ]; then
      echo "Git (Branch): $(sx::git::current_branch)"
      return 0
    fi
  fi

  echo 'dev'
}
