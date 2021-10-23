#!/usr/bin/env bash

function sx::termux::configure-device() {
  sx::require 'pkg'

  local -r installed_packages="$(pkg list-installed 2>/dev/null)"
  local -r packages_to_install=(
    'openssh'
    'termux-services'
    'jq'
    'vim'
  )

  for package_to_install in "${packages_to_install[@]}"; do
    if ! echo "${installed_packages}" | grep -q "${package_to_install}/"; then
      pkg install -y "${package_to_install}"
    fi
  done
  echo

  if ! [ -d "${PREFIX}/var/service/sshd/" ] \
    || ! [ -f "${PREFIX}/var/service/sshd/down" ]; then
    sv-enable sshd
  fi

  local -r profile_path="${HOME}/.profile"
  local -r start_sshd_cmd='sv up sshd'

  if ! [ -f "${profile_path}" ] \
    || ! grep -q "${start_sshd_cmd}" "${profile_path}"; then
    echo "${start_sshd_cmd}" >>"${profile_path}"
  fi

  # TODO: prompt asking the public key (e.g. ~/.ssh/id_rsa.pub)

  sx::log::info 'Now you must restart Termux!'
}
