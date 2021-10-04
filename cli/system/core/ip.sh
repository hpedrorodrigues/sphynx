#!/usr/bin/env bash

function sx::system::ip::private() {
  sx::system::check_requirements

  ifconfig \
    | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' \
    | grep -Eo '([0-9]*\.){3}[0-9]*' \
    | grep -v '127.0.0.1'
}

function sx::system::ip::public() {
  sx::system::check_requirements
  sx::require_network

  local -r commands=(
    'dig @resolver1.opendns.com ANY myip.opendns.com +short -4'
    'curl "https://api.ipify.org?format=json" --ipv4 --silent | jq ".ip" --monochrome-output --raw-output'
    'curl "https://www.jsonip.com"            --ipv4 --silent | jq ".ip" --monochrome-output --raw-output'
    'curl "https://ipinfo.io/ip"              --ipv4 --silent'
    'curl "https://ifconfig.me/ip"            --ipv4 --silent'
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

function sx::system::ip::gateway() {
  sx::system::check_requirements

  if sx::os::is_osx; then
    netstat -rn | grep 'default' | head -n 1 | awk '{ print $2 }'
  else
    ip route | grep 'default' | awk '{ print $3 }'
  fi
}
