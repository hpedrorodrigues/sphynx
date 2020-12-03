#!/usr/bin/env bash

function sx::network::current::ssid() {
  if sx::os::is_osx; then
    sx::osx::airport -I en1 | grep -i SSID | tail -n 1 | sed 's/SSID://g' | sed 's/ //g'
  else
    nmcli -t -f active,ssid dev wifi | grep -E '^yes' | cut -d ':' -f2
  fi
}

function sx::network::is_ip_reachable() {
  local -r ip="${1}"

  ping -c1 -W3 "${ip}" &>/dev/null
}
