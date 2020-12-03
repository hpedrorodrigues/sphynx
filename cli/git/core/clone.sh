#!/usr/bin/env bash

function sx::git::clone::repository() {
  sx::require 'git'

  local -r username="${1:-}"
  if [ -z "${username}" ]; then
    sx::log::fatal "This function needs a username as first argument"
  fi

  local -r project_name="${2:-}"
  if [ -z "${project_name}" ]; then
    sx::log::fatal "This function needs a project name as second argument"
  fi

  local -r project_url="git@github.com:${username}/${project_name}.git"
  local -r directory="${SX_GIT_FOLDER:-${PWD}}"

  git clone "${project_url}" "${directory}/${project_name}"
}
