#!/usr/bin/env bash

function sx::git::clone::https() {
  sx::require 'git'
  sx::require_env 'GITHUB_TOKEN'

  local -r username="${1:-}"
  if [ -z "${username}" ]; then
    sx::log::fatal 'This function needs a username as first argument'
  fi

  local -r project_name="${2:-}"
  if [ -z "${project_name}" ]; then
    sx::log::fatal 'This function needs a project name as second argument'
  fi

  local -r project_url="https://${GITHUB_TOKEN}@github.com/${username}/${project_name}.git"
  local -r directory="${SX_GIT_FOLDER:-${PWD}}"

  git clone "${project_url}" "${directory}/${project_name}"
}

function sx::git::clone::ssh() {
  sx::require 'git'

  local -r username="${1:-}"
  if [ -z "${username}" ]; then
    sx::log::fatal 'This function needs a username as first argument'
  fi

  local -r project_name="${2:-}"
  if [ -z "${project_name}" ]; then
    sx::log::fatal 'This function needs a project name as second argument'
  fi

  local -r project_url="git@github.com:${username}/${project_name}.git"
  local -r directory="${SX_GIT_FOLDER:-${PWD}}"

  git clone "${project_url}" "${directory}/${project_name}"
}
