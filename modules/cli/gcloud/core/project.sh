#!/usr/bin/env bash

function sx::gcloud::project() {
  sx::gcloud::check_requirements

  local -r query="${1:-}"
  local -r exact_project_id="${2:-}"
  local -r list_projects="${3:-false}"

  if [ -n "${exact_project_id}" ]; then
    sx::gcloud::project::change "${exact_project_id}"
  elif ${list_projects}; then
    local -r current_project="$(sx::gcloud::project::current)"

    while IFS='' read -r project; do
      if echo "${project}" | grep -q "${current_project}" 2>/dev/null; then
        sx::color::current_item::echo "${project}"
      else
        echo "${project}"
      fi
    done < <(sx::gcloud::project::list)
  elif sx::os::is_command_available 'fzf'; then
    local -r options="$(sx::gcloud_command::project::search "${query}")"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No resources found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf ${SX_FZF_ARGS})"

    if [ -n "${selected}" ]; then
      local -r project_id="$(echo "${selected}" | awk '{ print $1 }')"

      sx::gcloud::project::change "${project_id}"
    fi
  else
    export PS3=$'\n''Please, choose the resource: '$'\n'

    local options
    readarray -t options < <(sx::gcloud_command::project::search "${query}")

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No resources found'
    fi

    select selected in "${options[@]}"; do
      local -r project_id="$(echo "${selected}" | awk '{ print $1 }')"

      sx::gcloud::project::change "${project_id}"
      break
    done
  fi
}

function sx::gcloud_command::project::search() {
  local -r query="${1:-}"

  if [ -n "${query}" ]; then
    local -r selector="$(echo "${query}" | sx::string::lowercase)"
  else
    local -r selector='.*'
  fi

  local -r current_project="$(sx::gcloud::project::current)"

  while IFS='' read -r project; do
    if echo "${project}" | grep -q "${current_project}" 2>/dev/null; then
      sx::color::current_item::echo "${project}"
    else
      echo "${project}"
    fi
  done < <(sx::gcloud::project::list | grep -E "${selector}")
}
