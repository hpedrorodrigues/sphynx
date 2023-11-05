#!/usr/bin/env bash

function sx::security::certificate::print() {
  sx::security::check_requirements
  sx::require 'openssl'
  sx::require_network

  local -r host="${1:-}"

  if [ -z "${host}" ]; then
    sx::log::fatal 'This function needs a host as first argument'
  fi

  local -r info="$(
    echo -e 'GET / HTTP/1.0\nEOT' \
      | openssl s_client -connect "${host}:443" -servername "${host}" 2>&1
  )"

  if ! [[ ${info} == *'-----BEGIN CERTIFICATE-----'* ]]; then
    sx::log::fatal 'No certificate found'
  fi

  echo "${info}" | openssl x509
}

function sx::security::certificate::print_sans() {
  sx::security::check_requirements
  sx::require 'openssl'
  sx::require_network

  local -r host="${1:-}"

  if [ -z "${host}" ]; then
    sx::log::fatal 'This function needs a host as first argument'
  fi

  local -r info="$(
    echo -e 'GET / HTTP/1.0\nEOT' \
      | openssl s_client -connect "${host}:443" -servername "${host}" 2>&1
  )"

  if ! [[ ${info} == *'-----BEGIN CERTIFICATE-----'* ]]; then
    sx::log::fatal 'No certificate found'
  fi

  local -r certificate_options="no_aux, no_header, no_issuer, \
                                no_pubkey, no_serial, no_sigdump, \
                                no_signame, no_validity, no_version"
  local -r text=$(
    echo "${info}" | openssl x509 -text -certopt "${certificate_options}"
  )

  sx::log::info 'Common Name:\n'
  echo "${text}" \
    | grep 'Subject:' \
    | sed -e 's/^.*CN=//' \
    | sed -e 's/\/emailAddress=.*//'

  sx::log::info '\nSubject Alternative Name(s):\n'
  echo "${text}" \
    | grep -A 1 'Subject Alternative Name:' \
    | sed -e '2s/DNS://g' -e 's/ //g' \
    | tr ',' '\n' \
    | tail -n +2
}
