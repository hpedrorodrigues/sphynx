#!/usr/bin/env bash

function sx::workstation::setup() {
  sx::workstation::check_requirements
  sx::workstation::install_dependencies

  export ANSIBLE_CONFIG="${SPHYNX_DIR}/playbooks"

  if sx::os::is_macos; then
    local -r playbook_path="${ANSIBLE_CONFIG}/macos/main.yml"
  else
    local -r playbook_path="${ANSIBLE_CONFIG}/linux/main.yml"
  fi

  ansible-playbook "${playbook_path}" --ask-become-pass
}
