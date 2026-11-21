#!/usr/bin/env bash

function sx::github::release::list() {
  sx::github::check_requirements

  local -r username="${1}"
  local -r project_name="${2}"

  local -r releases_output="$(sx::github::api "repos/${username}/${project_name}/releases")"

  if [ -z "${releases_output}" ] || [ "$(echo "${releases_output}" | jq -r '.message' 2>/dev/null)" = 'Not Found' ]; then
    sx::log::fatal 'No releases found'
  fi

  local -r output="$(
    echo "${releases_output}" \
      | jq -r 'map([ .tag_name, .draft, .prerelease, .created_at, .html_url ] | join(", ")) | join("\n")'
  )"

  echo -e "TAG, DRAFT, PRERELEASE, CREATED_AT, URL\n${output}" | column -t -s ','
}

function sx::github::release::list_assets() {
  local -r username="${1}"
  local -r project_name="${2}"

  local -r latest_release_output="$(sx::github::api "repos/${username}/${project_name}/releases/latest")"
  local -r assets_url="$(echo "${latest_release_output}" | jq -r '.assets_url' 2>/dev/null)"

  if [ -z "${assets_url}" ] || [ "${assets_url}" = 'null' ]; then
    return 1
  fi

  local -r tag_name="$(echo "${latest_release_output}" | jq -r '.tag_name')"
  local -r tarball_url="https://github.com/${username}/${project_name}/archive/${tag_name}.tar.gz"
  local -r zipball_url="https://github.com/${username}/${project_name}/archive/${tag_name}.zip"

  local -r assets="$(
    echo "${project_name}-${tag_name}.tar.gz, ${tarball_url}"
    echo "${project_name}-${tag_name}.zip, ${zipball_url}"
    sx::github::api "${assets_url}" \
      | jq -r 'map([ .name, .browser_download_url ] | join(", ")) | join("\n")'
  )"

  echo "${assets}" | column -t -s ','
}

function sx::github::release::download_assets() {
  sx::github::check_requirements

  local -r username="${1}"
  local -r project_name="${2}"

  local -r options="$(sx::github::release::list_assets "${username}" "${project_name}")"

  if [ -z "${options}" ]; then
    sx::log::fatal 'No release or assets found'
  fi

  local -r selected="$(sx::select_one 'Please, choose the file' <<<"${options}")"

  if [ -n "${selected}" ]; then
    local -r name="$(echo "${selected}" | awk '{ print $1 }')"
    local -r url="$(echo "${selected}" | awk '{ print $2 }')"

    if [ -f "${name}" ]; then
      sx::log::fatal "A file named \"${name}\" already exists"
    fi

    sx::log::info "Downloading \"${url}\" into \"${name}\"...\n"
    sx::github::detect_api "${url}" >"${name}" && sx::log::info "Done! (File: ${name})"
  fi
}
