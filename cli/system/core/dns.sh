#!/usr/bin/env bash

function sx::system::flush_dns_cache() {
  sx::system::check_requirements

  if sx::os::is_osx; then
    sudo dscacheutil -flushcache
    sudo killall -HUP mDNSResponder mDNSResponderHelper
  else
    sudo systemd-resolve --flush-caches
    sudo systemctl restart nscd
  fi
}

function sx::system::query_dns() {
  sx::system::check_requirements
  sx::require_network

  local domain="${*}"

  if sx::os::is_command_available 'ping'; then
    sx::log::info ">> PING's output\n"
    ping -q -c1 -t1 "${domain}" \
      | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}" \
      | sort -u \
      || true
  fi

  if sx::os::is_command_available 'dig'; then
    sx::log::info "\n\n>> DIG's output"

    local name_servers
    readarray -t name_servers < <(
      grep -i '^nameserver' /etc/resolv.conf \
        | awk '{ print $2 }' \
        | xargs -I % echo 'Current,%'
    )

    name_servers+=(
      "Google's,8.8.8.8"
      "VeriSign's,64.6.64.6"
      "Cloudflare's,1.1.1.1"
    )

    local server_ip
    local server_owner
    for name_server in ${name_servers[*]}; do
      server_owner="$(echo "${name_server}" | cut -d ',' -f 1)"
      server_ip="$(echo "${name_server}" | cut -d ',' -f 2)"

      sx::log::info "\n> ${server_owner} name server (${server_ip})\n"

      if sx::network::is_ipv4 "${server_ip}"; then
        dig -4 "@${server_ip}" +noall +answer +time=3 "${domain}" || true
      elif sx::network::is_ipv6 "${server_ip}"; then
        dig -6 "@${server_ip}" +noall +answer +time=3 "${domain}" || true
      else
        sx::log::fatal "Invalid name server address \"${server_ip}\""
      fi
    done
  fi
}
