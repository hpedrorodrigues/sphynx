#!/usr/bin/env bash

export DOTBOT_CONFIG_FILE="${DOTBOT_CONFIG_FILE:-${SPHYNX_DIR}/modules/dotfiles/dotbot.conf.yaml}"
export PLAYBOOKS_DIRECTORY="${PLAYBOOKS_DIRECTORY:-${SPHYNX_DIR}/modules/playbooks}"

export SX_DOTBOT="${SX_DOTBOT:-dotbot}"

function sx::workspace::setup() {
  sx::workspace::check_requirements
  sx::require_network
  sx::workspace::require_homebrew
  sx::workspace::install_dependencies

  export ANSIBLE_CONFIG="${PLAYBOOKS_DIRECTORY}"

  if sx::os::is_macos; then
    local -r playbook_path="${ANSIBLE_CONFIG}/macos/main.yml"
  else
    local -r playbook_path="${ANSIBLE_CONFIG}/linux/main.yml"
  fi

  ansible-playbook "${playbook_path}" \
    --extra-vars="sphynx_directory=${SPHYNX_DIR}" \
    --ask-become-pass
}

function sx::workspace::setup_dotfiles() {
  sx::workspace::check_requirements

  if ! sx::os::is_command_available "${SX_DOTBOT}" && ! [ -f "${SX_DOTBOT}" ]; then
    sx::log::fatal "The command-line \"${SX_DOTBOT}\" is not available"
  fi

  command "${SX_DOTBOT}" -c "${DOTBOT_CONFIG_FILE}"
}
