#!/usr/bin/env bash

export DOTBOT_CONFIG_FILE="${DOTBOT_CONFIG_FILE:-${SPHYNX_DIR}/modules/dotfiles/dotbot.conf.yaml}"

function sx::workstation::setup() {
  sx::workstation::check_requirements
  sx::require_network
  sx::workstation::require_homebrew
  sx::workstation::install_dependencies

  export ANSIBLE_CONFIG="${SPHYNX_DIR}/playbooks"

  if sx::os::is_macos; then
    local -r playbook_path="${ANSIBLE_CONFIG}/macos/main.yml"
  else
    local -r playbook_path="${ANSIBLE_CONFIG}/linux/main.yml"
  fi

  ansible-playbook "${playbook_path}" --ask-become-pass
}

function sx::workstation::setup_dotfiles() {
  sx::workstation::check_requirements
  sx::require 'dotbot'

  dotbot -c "${DOTBOT_CONFIG_FILE}"
}
