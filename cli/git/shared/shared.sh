#!/usr/bin/env bash

function sx::git::check_repository() {
  local -r remote_url="$(sx::git::remote::url)"

  if [ -z "${remote_url}" ]; then
    sx::log::fatal 'You are running this command outside a git repository'
  fi
}

function sx::git::check_requirements() {
  sx::require 'git'
  sx::git::check_repository
}
