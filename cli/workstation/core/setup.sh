#!/usr/bin/env bash

function sx::workstation::setup() {
  sx::workstation::check_requirements
  sx::workstation::install_dependencies

  local -r playbooks_home="${SPHYNX_DIR}/playbooks"

  export ANSIBLE_CONFIG="${playbooks_home}"

  if sx::os::is_osx; then
    ansible-playbook "${playbooks_home}/osx/main.yml" --ask-become-pass
  else
    ansible-playbook "${playbooks_home}/linux/main.yml" --ask-become-pass
  fi
}
