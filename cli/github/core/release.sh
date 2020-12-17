#!/usr/bin/env bash

function sx::github::release::list() {
  sx::github::check_requirements

  local -r username="${1}"
  local -r project_name="${2}"

  local -r output=$(sx::github::api "repos/${username}/${project_name}/releases" \
    | jq -r 'map([ .tag_name, .draft, .prerelease, .created_at, .html_url ] | join(", ")) | join("\n")')

  echo -e "TAG, DRAFT, PRERELEASE, CREATED_AT, URL\n${output}" | column -t -s ','
}

function sx::github::release::list_assets() {
  local -r username="${1}"
  local -r project_name="${2}"

  local -r assets_url="$(sx::github::api "repos/${username}/${project_name}/releases/latest" | jq -r '.assets_url')"

  if [ -z "${assets_url}" ] || [ "${assets_url}" = 'null' ]; then
    sx::log::fatal 'No releases found'
  fi

  sx::github::api "${assets_url}" \
    | jq -r 'map([ .name, .browser_download_url ] | join(", ")) | join("\n")' \
    | column -t -s ','
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

      sx::github::browser_api "${url}" >"${name}" && sx::log::info "Done! (File: ${name})"
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

      sx::github::browser_api "${url}" >"${name}" && sx::log::info "Done! (File: ${name})"
      break
    done
  fi
}
