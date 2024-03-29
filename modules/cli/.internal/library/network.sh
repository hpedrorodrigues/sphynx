#!/usr/bin/env bash

function sx::network::current::ssid() {
  if sx::os::is_macos; then
    sx::macos::airport -I en1 | grep -i SSID | tail -n 1 | sed 's/SSID://g' | sed 's/ //g'
  else
    nmcli -t -f active,ssid dev wifi | grep -E '^yes' | cut -d ':' -f2
  fi
}

function sx::network::has_connection() {
  sx::network::can_reach 'google.com'
}

function sx::network::can_reach() {
  sx::require 'ping'

  local -r host="${1}"

  if [ -z "${host}" ]; then
    sx::log::fatal 'This function needs a host as first argument'
  fi

  ping -q -c1 -W10 "${host}" &>/dev/null
}

function sx::network::is_ipv4() {
  local -r ip="${1}"

  if [ -z "${ip}" ]; then
    sx::log::fatal 'This function needs an IP as first argument'
  fi

  if [[ "${ip}" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    while IFS='.' read -ra blocks; do
      for block in "${blocks[@]}"; do
        if ! [[ "${block}" -ge 0 ]] || ! [[ "${block}" -le 255 ]]; then
          return 1
        fi
      done
    done <<<"${ip}"

    return 0
  fi

  return 1
}

function sx::network::is_ipv6() {
  local -r ip="${1}"

  if [ -z "${ip}" ]; then
    sx::log::fatal 'This function needs an IP as first argument'
  fi

  [[ "${ip}" =~ ^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$ ]]
}
