#!/usr/bin/env bash

function sx::android::instrumentation::list() {
  sx::android::check_requirements "${1:-}"

  local -r serial="$(sx::android::target_device "${1:-}")"

  sx::android::shell "${serial}" pm list instrumentation
}

function sx::android::instrumentation::select_package() {
  local -r query="${1:-}"
  local -r serial="${2:-}"

  local candidates
  readarray -t candidates < <(
    sx::android::instrumentation::list "${serial}" \
      | cut -d ':' -f 2 \
      | cut -d '/' -f 1 \
      | sort -u \
      | grep -i -- "${query:-.*}"
  )

  if [ "${#candidates[@]}" -eq 0 ]; then
    sx::log::fatal "No instrumentation apps found matching \"${query}\""
  fi

  printf '%s\n' "${candidates[@]}" | sx::android::select_one
}

function sx::android::instrumentation::uninstall() {
  sx::android::check_requirements "${2:-}"

  local -r query="${1:-}"
  local -r serial="$(sx::android::target_device "${2:-}")"

  local -r package="$(sx::android::instrumentation::select_package "${query}" "${serial}")"

  if [ -z "${package}" ]; then
    return 1
  fi

  sx::log::info "Uninstalling instrumentation application: \"${package}\"\n"

  sx::android::shell "${serial}" pm uninstall "${package}"
}
