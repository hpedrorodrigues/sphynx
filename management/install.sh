#!/usr/bin/env bash

# References
# - https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent
# - https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints

# Running
# bash -c "$(curl -fsSL https://raw.githubusercontent.com/hpedrorodrigues/sphynx/fresh-install/management/install.sh)" -- <email>

set -o errexit
set -o nounset
set -o pipefail

readonly key_type='ed25519'
readonly authentication_key_file="${HOME}/.ssh/id_ed25519"
readonly known_hosts_file="${HOME}/.ssh/known_hosts"
readonly user_email="${1:-}"
readonly personal_directory="${HOME}/Code/Personal"
readonly sphynx_directory="${personal_directory}/sphynx"
readonly secrets_directory="${personal_directory}/secrets"

function log_info() {
  echo
  echo "> ${*}"
  echo
}

##########|> SSH

if [ -z "${user_email}" ]; then
  echo >&2 "User email not provided! It's required as first argument."
  exit 1
fi

if [ -f "${authentication_key_file}" ]; then
  log_info 'SSH is already installed. Ignoring...'
else
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

  pbcopy <"${authentication_key_file}.pub"
  log_info 'Public key copied to clipboard! Please configure a new SSH key on GitHub!'

  open 'https://github.com/settings/keys'
fi

##########|> Xcode Command Line Tools

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

##########|> Rosetta

if [ "$(arch)" = 'arm64' ] && arch -arch x86_64 uname -m &>/dev/null; then
  log_info 'Rosetta is already installed. Ignoring...'
else
  log_info 'Rosetta is not installed. Installing it...'
  softwareupdate --install-rosetta --agree-to-license
fi

##########|> Homebrew

if hash 'brew' 2>/dev/null || [ -f '/opt/homebrew/bin/brew' ]; then
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
