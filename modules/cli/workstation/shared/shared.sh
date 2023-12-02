#!/usr/bin/env bash

if sx::os::is_macos; then
  export SX_HOMEBREW_PATH="${SX_HOMEBREW_PATH:-/opt/homebrew/bin/brew}"
elif sx::os::is_linux; then
  export SX_HOMEBREW_PATH="${SX_HOMEBREW_PATH:-/home/linuxbrew/.linuxbrew/bin/brew}"
else
  export SX_HOMEBREW_PATH="${SX_HOMEBREW_PATH}"
fi

function sx::workstation::require_homebrew() {
  if ! sx::os::is_command_available 'brew' && [ -f "${SX_HOMEBREW_PATH}" ]; then
    eval "$(command "${SX_HOMEBREW_PATH}" shellenv)"
  fi

  sx::require 'brew' 'Homebrew'
}

function sx::workstation::check_requirements() {
  sx::require_supported_os
}

function sx::workstation::install_dependencies() {
  if ! sx::os::is_command_available 'ansible'; then
    brew install 'ansible'
  fi
}
