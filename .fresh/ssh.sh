#!/usr/bin/env bash

# References
# - https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent
# - https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints

set -o errexit
set -o nounset
set -o pipefail

readonly key_type='ed25519'
readonly authentication_key_file="${HOME}/.ssh/id_ed25519"
readonly config_file="${HOME}/.ssh/config"
readonly known_hosts_file="${HOME}/.ssh/known_hosts"
readonly user_email="${1:-}"

function log_info() {
  echo
  echo "> ${@}"
  echo
}

if [ -f "${authentication_key_file}" ]; then
  echo 'Key file already exists! Skipping...'
  exit 0
elif [ -z "${user_email}" ]; then
  echo >&2 "User email not provided! It's required as first argument."
  exit 1
fi

log_info 'Generating a new SSH key...'
ssh-keygen \
  -t "${key_type}" \
  -C "${user_email}" \
  -f "${authentication_key_file}"

log_info 'Adding Github fingerprints to known hosts...'
ssh-keyscan -t 'rsa' 'github.com' >> "${known_hosts_file}"
ssh-keyscan -t 'ecdsa' 'github.com' >> "${known_hosts_file}"
ssh-keyscan -t 'ed25519' 'github.com' >> "${known_hosts_file}"

cat "${authentication_key_file}.pub" | sx system clipboard copy
log_info 'Public key copied to clipboard!'
