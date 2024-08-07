#!/usr/bin/env bash

# Requirements:
# - curl
# - git
#
# Running:
# bash -c "$(curl -fsSL https://raw.githubusercontent.com/hpedrorodrigues/sphynx/main/install/install.sh)"

set -o errexit
set -o nounset
set -o pipefail

readonly key_type='ed25519'
readonly authentication_key_file="${HOME}/.ssh/id_ed25519"
readonly known_hosts_file="${HOME}/.ssh/known_hosts"
readonly personal_directory="${HOME}/Code/Personal"
readonly sphynx_directory="${personal_directory}/sphynx"
readonly secrets_directory="${personal_directory}/secrets"

function log_info() {
  echo
  echo "> ${*}"
  echo
}

function is_macos() {
  [ "$(uname)" = 'Darwin' ]
}

##########|> SSH

if [ -f "${authentication_key_file}" ]; then
  log_info 'SSH is already installed. Ignoring...'
else
  echo 'Enter your email: '
  echo
  read -r user_email

  if [ -z "${user_email}" ] || ! [[ "${user_email}" =~ ^.*@.*\..*$ ]]; then
    echo >&2 "User email not provided or invalid!"
    exit 1
  fi

  log_info 'Generating a new SSH key...'
  ssh-keygen \
    -t "${key_type}" \
    -C "${user_email}" \
    -f "${authentication_key_file}"

  log_info 'Adding Github fingerprints to known hosts...'
  {
    ssh-keyscan -t 'rsa' 'github.com'
    ssh-keyscan -t 'ecdsa' 'github.com'
    ssh-keyscan -t 'ed25519' 'github.com'
  } >>"${known_hosts_file}"

  if is_macos; then
    pbcopy <"${authentication_key_file}.pub"
    log_info 'Public key copied to clipboard! Please configure a new SSH key on GitHub!'

    open 'https://github.com/settings/keys'
  else
    log_info 'Now, copy the public key content and configure a new SSH key on GitHub!'
    cat "${authentication_key_file}.pub"

    hash 'xdg-open' 2>/dev/null && xdg-open 'https://github.com/settings/keys'
  fi
fi

##########|> Xcode Command Line Tools

if is_macos; then
  if xcode-select --print-path &>/dev/null; then
    log_info 'Xcode Command Line Tools installed. Ignoring...'
  else
    log_info 'Xcode Command Line Tools not installed. Installing it...'

    xcode-select --install

    until xcode-select --print-path &>/dev/null; do
      echo 'Waiting for Xcode Command Line Tools to be installed...'
      sleep 5
    done
  fi
fi

##########|> Rosetta

if is_macos; then
  if [ "$(arch)" = 'arm64' ] && arch -arch x86_64 uname -m &>/dev/null; then
    log_info 'Rosetta is already installed. Ignoring...'
  else
    log_info 'Rosetta is not installed. Installing it...'
    softwareupdate --install-rosetta --agree-to-license
  fi
fi

##########|> Homebrew

if hash 'brew' 2>/dev/null || [ -f '/opt/homebrew/bin/brew' ] || [ -f '/home/linuxbrew/.linuxbrew/bin/brew' ]; then
  log_info 'Homebrew is already installed. Ignoring...'
else
  log_info 'Homebrew is not installed. Installing it...'

  bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

##########|> Personal Directory

if ! [ -d "${personal_directory}" ]; then
  mkdir -p "${personal_directory}"
fi

##########|> Sphynx

if [ -d "${sphynx_directory}" ]; then
  log_info 'Sphynx is already cloned. Ignoring...'
else
  log_info 'Sphynx is not cloned. Cloning it...'

  (cd "${personal_directory}" && git clone git@github.com:hpedrorodrigues/sphynx.git)
fi

##########|> Secrets

if [ -d "${secrets_directory}" ]; then
  log_info 'Secrets project is already cloned. Ignoring...'
else
  log_info 'Secrets project is not cloned. Cloning it...'

  (cd "${personal_directory}" && git clone git@github.com:hpedrorodrigues/secrets.git)
fi

##########|> Workstation Setup

(cd "${sphynx_directory}" && ./sx workstation setup)

##########|> Finish

log_info 'Done!'
