#!/usr/bin/env bash

function sx::git::pull_request::preview() {
  sx::git::check_requirements

  local -r current_branch="$(sx::git::current_branch)"
  local -r base_url="$(sx::git::base_url)"

  sx::os::browser::open "${base_url}/compare/${current_branch}?expand=1"
}
