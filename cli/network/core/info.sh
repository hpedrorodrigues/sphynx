#!/usr/bin/env bash

function sx::network::check_requirements() {
  sx::require 'sipcalc'
  sx::require 'subnetcalc'
}

function sx::network::mask_hex() {
  local -r ip="${1}"

  ifconfig \
    | grep -E 'inet\s(192|172|10)' \
    | grep "${ip}" \
    | awk '{ for (i = 1; i <= NF; i++) { if ($(i - 1) == "netmask") { print $i } } }'
}

function sx::network::mask_bits() {
  local -r host_ip="${1}"
  local -r mask_hex="${2}"

  sipcalc "${host_ip}" "${mask_hex}" \
    | grep 'Network mask (bits)' \
    | awk '{ print $5 }'
}

function sx::network::ip() {
  local -r host_ip="${1}"
  local -r mask_hex="${2}"

  sipcalc "${host_ip}" "${mask_hex}" \
    | grep 'Network address' \
    | awk '{ print $4 }'
}

function sx::network::info() {
  sx::network::check_requirements

  local private_ip
  for private_ip in $(sx::ip::private); do

    local network_name="$(sx::network::current::ssid)"
    local gateway_ip="$(sx::ip::gateway)"
    local public_ip="$(sx::ip::public)"
    local mask_hex="$(sx::network::mask_hex "${private_ip}")"
    local network_ip="$(sx::network::ip "${private_ip}" "${mask_hex}")"
    local mask_bits="$(sx::network::mask_bits "${private_ip}" "${mask_hex}")"

    sx::log::info "\n\n> Network: ${network_name} (${network_ip}/${mask_bits})\n"
    sx::log::info "|-- Gateway IP: ${gateway_ip}"
    sx::log::info "|-- Private IP: ${private_ip}"
    sx::log::info "|-- Public  IP: ${public_ip}\n"

    sx::log::info "|-- Sipcalc (https://github.com/sii/sipcalc)"
    sx::log::info '|--'
    sx::log::info "|-- ${private_ip} ${mask_hex}"
    sx::log::info ''
    sipcalc "${private_ip}" "${mask_hex}" | sed 's/^-//g'

    sx::log::info "|-- Subnetcalc (https://github.com/dreibh/subnetcalc)"
    sx::log::info '|--'
    sx::log::info "|-- ${gateway_ip}/${mask_bits}"
    sx::log::info ''
    subnetcalc "${gateway_ip}/${mask_bits}"
  done
}
