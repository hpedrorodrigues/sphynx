#!/usr/bin/env bash

export SX_VERSION_SPACING='  '

function sx::self::version() {
  sx::log::info 'Runtime:'
  sx::log::info "${SX_VERSION_SPACING}$(sx::python --version)"

  sx::log::info 'Sphynx:'
  sx::self::version::internal
}

function sx::self::version::internal() {
  sx::require_supported_os

  if sx::os::is_linux; then
    local -r package_manager_name='Linuxbrew'
  else
    local -r package_manager_name='Homebrew'
  fi

  local -r resolved_path="$(sx::os::realpath "${SPHYNX_EXEC}")"
  if [[ "${resolved_path}" == */Cellar/sphynx/*/bin/* ]]; then
    local -r versioned_path="${resolved_path#*/Cellar/sphynx/}"
    sx::log::info "${SX_VERSION_SPACING}${package_manager_name}: ${versioned_path%%/bin/*}"
    return 0
  fi

  if sx::os::is_command_available 'git'; then
    sx::log::info "${SX_VERSION_SPACING}Git (Branch): $(
      cd -- "${SPHYNX_DIR}" >/dev/null 2>&1 || exit 1
      sx::git::current_branch
    )"
  else
    sx::log::errn "${SX_VERSION_SPACING}Not available"
    exit 1
  fi
}
