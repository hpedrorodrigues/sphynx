#!/usr/bin/env bash

export ADB_TCP_PORT="${ADB_TCP_PORT:-5555}"

function sx::android::device::ip() {
  sx::android::check_requirements

  sx::android::shell ip -4 addr show wlan0 | grep inet | awk '{ print $2 }' | sed 's/\/[0-9]*//g' # ipv4
}

function sx::android::device::powered_by() {
  function _check_status() {
    sx::android::shell dumpsys battery | grep powered | grep -i "${*}" | grep 'true'
  }

  local -r ac="$(_check_status 'ac')"
  local -r usb="$(_check_status 'usb')"
  local -r wireless="$(_check_status 'wireless')"

  if [ -z "${ac}" ] && [ -z "${usb}" ] && [ -z "${wireless}" ]; then
    sx::log::info 'No charging'
  elif [ -n "${ac}" ]; then
    sx::log::info 'AC'
  elif [ -n "${usb}" ]; then
    sx::log::info 'USB'
  else
    sx::log::info 'Wireless'
  fi
}

function sx::android::device::connect_via_tcp() {
  sx::android::check_requirements
  sx::android::ensure_wifi_enabled

  local -r device_ip="$(sx::android::device::ip)"

  if ! sx::network::is_ip_reachable "${device_ip}"; then
    local -r network_name="$(sx::network::current::ssid)"

    sx::log::fatal "The Android device ip \"${device_ip}\" is not accessible from your network (${network_name})"
  fi

  sx::android::adb tcpip "${ADB_TCP_PORT}" \
    && sx::android::adb connect "${device_ip}" \
    && sx::log::info 'Now you can remove usb cable'
}

function sx::android::device::disconnect_via_tcp() {
  sx::android::check_requirements
  sx::android::ensure_wifi_enabled

  local -r device_ip="$(sx::android::device::ip)"

  sx::android::adb disconnect "${device_ip}:${ADB_TCP_PORT}"
}

function sx::android::device::battery_stats() {
  sx::android::check_requirements

  function _battery_dump_prop() {
    local -r property_name="${1}"
    sx::android::shell dumpsys battery | grep -i "  ${property_name}" | awk '{ print $2 }'
  }

  local -r powered_by="$(sx::android::device::powered_by)"
  local -r level="$(_battery_dump_prop 'level')"
  local -r scale="$(_battery_dump_prop 'scale')"
  local -r voltage="$(_battery_dump_prop 'voltage')"
  local -r temperature="$(_battery_dump_prop 'temperature')"
  local -r technology="$(_battery_dump_prop 'technology')"

  sx::log::info "${technology}\n"
  sx::log::info "|-- Charger: ${powered_by}"
  sx::log::info "|-- Level: ${level}/${scale}"
  sx::log::info "|-- Voltage: ${voltage}"
  sx::log::info "|-- Temperature: $(echo "scale=2; ${temperature}.0 / 10" | bc)°C"
}
