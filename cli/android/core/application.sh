#!/usr/bin/env bash

function sx::android::application::clear_data() {
  sx::android::check_requirements

  local -r filter="${1}"
  local -r package="$(sx::android::find_package "${filter}")"

  sx::android::ensure_package_exists "${filter}"

  sx::log::info "Clearing application data: \"${package}\""

  sx::android::shell input keyevent KEYCODE_HOME
  sx::android::shell pm clear "${package}"
}

function sx::android::application::find() {
  sx::android::check_requirements

  local -r filter="${1}"

  sx::android::list_packages | grep --color=always -i "${filter}"
}

function sx::android::application::stop() {
  sx::android::check_requirements

  local -r filter="${1}"
  local -r package="$(sx::android::find_package "${filter}")"

  sx::android::ensure_package_exists "${filter}"

  local -r application_pid="$(sx::android::pidof "${package}")"

  if [ -z "${application_pid}" ]; then
    sx::log::err "Application \"${package}\" is not running"
  else
    sx::log::info "Stopping application: \"${package}\""
    sx::android::shell am force-stop "${package}"
  fi
}

function sx::android::application::list_packages() {
  sx::android::check_requirements

  sx::android::list_packages
}
