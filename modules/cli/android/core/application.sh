#!/usr/bin/env bash

function sx::android::application::search() {
  sx::android::check_requirements "${2:-}"

  local -r query="${1:-}"
  local -r serial="$(sx::android::target_device "${2:-}")"

  sx::android::select_package "${query}" "${serial}"
}

function sx::android::application::clear_data() {
  sx::android::check_requirements "${2:-}"

  local -r query="${1:-}"
  local -r serial="$(sx::android::target_device "${2:-}")"

  local -r package="$(sx::android::select_package "${query}" "${serial}")"

  if [ -z "${package}" ]; then
    return 1
  fi

  sx::log::info "Clearing application data: \"${package}\""

  sx::android::shell "${serial}" input keyevent KEYCODE_HOME
  sx::android::shell "${serial}" pm clear "${package}"
}

function sx::android::application::list() {
  sx::android::check_requirements "${1:-}"

  local -r serial="$(sx::android::target_device "${1:-}")"

  sx::android::list_packages "${serial}"
}

function sx::android::application::stop() {
  sx::android::check_requirements "${2:-}"

  local -r query="${1:-}"
  local -r serial="$(sx::android::target_device "${2:-}")"

  local -r package="$(sx::android::select_package "${query}" "${serial}")"

  if [ -z "${package}" ]; then
    return 1
  fi

  local -r application_pid="$(sx::android::pidof "${serial}" "${package}")"

  if [ -z "${application_pid}" ]; then
    sx::log::err "Application \"${package}\" is not running"
  else
    sx::log::info "Stopping application: \"${package}\""
    sx::android::shell "${serial}" am force-stop "${package}"
  fi
}

function sx::android::application::uninstall() {
  sx::android::check_requirements "${2:-}"

  local -r query="${1:-}"
  local -r serial="$(sx::android::target_device "${2:-}")"

  local -r package="$(sx::android::select_package "${query}" "${serial}")"

  if [ -z "${package}" ]; then
    return 1
  fi

  sx::log::info "Uninstalling application: \"${package}\""

  sx::android::shell "${serial}" pm uninstall "${package}"
}
