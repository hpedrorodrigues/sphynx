#!/usr/bin/env bash

readonly fetch_timeout_seconds='10'
readonly default_port='443'

function sx::security::certificate::fetch() {
  sx::security::check_requirements
  sx::require 'openssl'
  sx::require_network

  local -r host_port="${1:-}"
  if [ -z "${host_port}" ]; then
    sx::log::fatal 'This function needs a host (optionally host:port) as first argument'
  fi

  local -r host="${host_port%%:*}"
  local port="${default_port}"
  if [[ "${host_port}" == *:* ]]; then
    port="${host_port##*:}"
  fi

  local -r info="$(
    timeout "${fetch_timeout_seconds}" openssl s_client \
      -connect "${host}:${port}" \
      -servername "${host}" \
      </dev/null 2>&1
  )"

  if ! [[ ${info} == *'-----BEGIN CERTIFICATE-----'* ]]; then
    local -r reason="$(grep -v '^[[:space:]]*$' <<<"${info}" | tail -n 1)"
    sx::log::fatal "No certificate found for ${host}:${port}: ${reason}"
  fi

  echo "${info}"
}

function sx::security::certificate::print() {
  local -r info="$(sx::security::certificate::fetch "${1:-}")"

  if [ -z "${info}" ]; then
    return 1
  fi

  openssl x509 <<<"${info}"
}

function sx::security::certificate::sans() {
  local -r info="$(sx::security::certificate::fetch "${1:-}")"

  if [ -z "${info}" ]; then
    return 1
  fi

  sx::log::info 'Common Name:\n'
  openssl x509 -noout -subject -nameopt sep_multiline <<<"${info}" \
    | sed -n 's/^[[:space:]]*CN[[:space:]]*=[[:space:]]*//p'

  sx::log::info '\nSubject Alternative Name(s):\n'
  openssl x509 -noout -ext subjectAltName <<<"${info}" \
    | tail -n +2 \
    | tr ',' '\n' \
    | sed -E 's/^[[:space:]]*DNS://'
}

function sx::security::certificate::info() {
  local -r info="$(sx::security::certificate::fetch "${1:-}")"

  if [ -z "${info}" ]; then
    return 1
  fi

  openssl x509 -text -noout <<<"${info}"
}
