#!/usr/bin/env bash

function sx::android::service::ensure_valid_state() {
  local -r state="${1}"

  if [ "${state}" != 'enable' ] && [ "${state}" != 'disable' ]; then
    sx::log::fatal "Invalid state provided: \"${state}\". Possible [enable|disable]."
  fi
}

function sx::android::service::change_wifi_state() {
  sx::android::check_requirements

  local -r state="${1}"

  sx::android::service::ensure_valid_state "${state}"

  sx::android::shell svc wifi "${state}"
}

function sx::android::service::change_bluetooth_state() {
  sx::android::check_requirements

  local -r state="${1}"

  sx::android::service::ensure_valid_state "${state}"

  sx::android::shell svc bluetooth "${state}"
}
