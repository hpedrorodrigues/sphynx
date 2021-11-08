#!/usr/bin/env bash

function sx::github::release::list() {
  sx::github::check_requirements

  local -r username="${1}"
  local -r project_name="${2}"

  local -r output="$(
    sx::github::api "repos/${username}/${project_name}/releases" \
      | jq -r 'map([ .tag_name, .draft, .prerelease, .created_at, .html_url ] | join(", ")) | join("\n")'
  )"

  echo -e "TAG, DRAFT, PRERELEASE, CREATED_AT, URL\n${output}" | column -t -s ','
}

function sx::github::release::list_assets() {
  local -r username="${1}"
  local -r project_name="${2}"

  local -r latest_release_output="$(sx::github::api "repos/${username}/${project_name}/releases/latest")"
  local -r assets_url="$(echo "${latest_release_output}" | jq -r '.assets_url')"

  if [ -z "${assets_url}" ] || [ "${assets_url}" = 'null' ]; then
    sx::log::fatal 'No releases found'
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

  if sx::os::is_command_available 'fzf'; then
    local -r options="$(sx::github::release::list_assets "${username}" "${project_name}")"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No assets found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf ${SX_FZF_ARGS})"

    if [ -n "${selected}" ]; then
      local name="$(echo "${selected}" | awk '{ print $1 }')"
      local url="$(echo "${selected}" | awk '{ print $2 }')"

      if [ -f "${name}" ]; then
        sx::log::fatal "A file named \"${name}\" already exists"
      fi

      sx::log::info "Downloading \"${url}\" into \"${name}\"...\n"
      sx::github::detect_api "${url}" >"${name}" && sx::log::info "Done! (File: ${name})"
    fi
  else
    export PS3=$'\n''Please, choose the file: '$'\n'

    local options
    readarray -t options < <(
      sx::github::release::list_assets "${username}" "${project_name}"
    )

    select selected in "${options[@]}"; do
      local name="$(echo "${selected}" | awk '{ print $1 }')"
      local url="$(echo "${selected}" | awk '{ print $2 }')"

      if [ -f "${name}" ]; then
        sx::log::fatal "A file named \"${name}\" already exists"
      fi

      sx::log::info "Downloading \"${url}\" into \"${name}\"...\n"
      sx::github::detect_api "${url}" >"${name}" && sx::log::info "Done! (File: ${name})"
      break
    done
  fi
}
