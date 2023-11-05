#!/usr/bin/env bash

function sx::android::instrumentation::list() {
  sx::android::check_requirements

  sx::android::shell pm list instrumentation
}

function sx::android::instrumentation::find_package() {
  local -r filter="${1}"

  sx::android::instrumentation::list \
    | grep -i "${filter}" \
    | head -n 1 \
    | cut -d ':' -f 2 \
    | cut -d '/' -f 1
}

function sx::android::instrumentation::ensure_package_exists() {
  local -r filter="${1}"
  local -r package="$(sx::android::instrumentation::find_package "${filter}")"

  if [ -z "${package}" ]; then
    sx::log::errn "No matches for \"${filter}\""
    sx::log::errn "\n==> Available instrumentation apps:\n"
    sx::log::fatal "$(sx::android::instrumentation::list)"
  fi
}

function sx::android::instrumentation::uninstall() {
  sx::android::check_requirements

  local -r filter="${1}"

  sx::android::instrumentation::ensure_package_exists "${filter}"

  local -r full_package="$(sx::android::instrumentation::find_package "${filter}")"

  sx::log::info "Uninstalling instrumentation application: \"${full_package}\"\n"

  sx::android::shell pm uninstall "${full_package}"
}
