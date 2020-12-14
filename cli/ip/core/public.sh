#!/usr/bin/env bash

function sx::ip::public() {
  sx::require_network

  local -r commands=(
    'dig @resolver1.opendns.com ANY myip.opendns.com +short -4'
    'curl https://ipinfo.io/ip --ipv4 --silent'
    'curl https://ifconfig.me/ip --ipv4 --silent'
    'curl https://www.jsonip.com --ipv4 --silent | jq ".ip" --monochrome-output --raw-output'
  )

  local public_ip=''
  for cmd in "${commands[@]}"; do
    public_ip="$(eval "${cmd}" 2>/dev/null)"
    if [ -n "${public_ip}" ]; then
      sx::log::info "${public_ip}"
      break
    fi
  done

  if [ -z "${public_ip}" ]; then
    sx::log::fatal 'Cannot determine the public IP'
  fi
}
