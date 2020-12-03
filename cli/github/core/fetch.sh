#!/usr/bin/env bash

function sx::github::fetch::file() {
  sx::github::check_requirements

  local -r owner="${1}"
  local -r project_name="${2}"
  local -r filepath="${3}"

  sx::github::content_api "${owner}/${project_name}/master/${filepath}"
}
