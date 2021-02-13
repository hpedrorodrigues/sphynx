#!/usr/bin/env bash

export PYTHON_VERSION_XY='3.9'
export PYTHON_VERSION_XYZ="${PYTHON_VERSION_XY}.1"

if sx::os::is_osx; then
  export PATH="/Library/Frameworks/Python.framework/Versions/${PYTHON_VERSION_XY}/bin:${PATH}:${HOME}/Library/Python/${PYTHON_VERSION_XY}/bin"
else
  export PATH="${PATH}:${HOME}/.local/bin"
fi

function sx::playbook::install_dependencies() {
  if sx::os::is_linux; then
    if ! sx::os::is_command_available 'pip3'; then
      sudo apt-get install -y python3-pip python3-apt
    fi
  elif sx::os::is_osx; then
    if ! sx::os::is_command_available 'pip3'; then
      sudo xcode-select --install

      local -r binary_url="https://www.python.org/ftp/python/${PYTHON_VERSION_XYZ}/python-${PYTHON_VERSION_XYZ}-macosx10.9.pkg"
      local -r binary_path="/tmp/$(basename "${binary_url}")"

      curl "${binary_url}" -o "${binary_path}"

      sudo installer -pkg "${binary_path}" -target '/'
    fi
  fi

  if ! sx::os::is_command_available 'ansible'; then
    pip3 install --upgrade pip

    pip3 install ansible --user
  fi
}

function sx::playbook::run() {
  sx::require_supported_os
  sx::require_network
  sx::playbook::install_dependencies

  local -r playbooks_home="${SPHYNX_DIR}/.playbook"

  export ANSIBLE_CONFIG="${playbooks_home}"

  if sx::os::is_osx; then
    ansible-playbook "${playbooks_home}/osx/main.yml"
  else
    ansible-playbook \
      "${playbooks_home}/linux/main.yml" \
      --ask-become-pass
  fi
}
