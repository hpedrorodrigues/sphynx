#!/usr/bin/env bash

export DOTBOT_CONFIG_FILE="${DOTBOT_CONFIG_FILE:-${SPHYNX_DIR}/modules/dotfiles/dotbot.conf.yaml}"
export PLAYBOOKS_DIRECTORY="${PLAYBOOKS_DIRECTORY:-${SPHYNX_DIR}/modules/playbooks}"

function sx::workstation::setup() {
  sx::workstation::check_requirements
  sx::require_network
  sx::workstation::require_homebrew
  sx::workstation::install_dependencies

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

function sx::workstation::setup_dotfiles() {
  sx::workstation::check_requirements
  sx::require 'dotbot'

  dotbot -c "${DOTBOT_CONFIG_FILE}"
}
