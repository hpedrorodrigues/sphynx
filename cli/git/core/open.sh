#!/usr/bin/env bash

function sx::git::open() {
  sx::git::check_requirements

  local -r file_path="${1:-.}"

  if ! [ -e "${file_path}" ]; then
    sx::log::fatal "No such file \"${file_path}\""
  fi

  local -r current_branch="$(sx::git::current_branch)"
  local -r default_branch="$(sx::git::default_branch)"
  local -r base_url="$(sx::git::base_url)"

  if [ "${file_path}" = '.' ]; then
    local -r full_url="$(
      if [ "${current_branch}" = "${default_branch}" ]; then
        echo "${base_url}"
      else
        echo "${base_url}/tree/${current_branch}"
      fi
    )"
  else
    local -r root="$(git rev-parse --show-toplevel | sed 's/\//\\\//g')"
    local -r relative_file_path="$(
      echo "${PWD}/${file_path}" | sed "s/${root}\///g"
    )"
    local -r full_url="${base_url}/blob/${current_branch}/${relative_file_path}"
  fi

  if [[ ${full_url} == *'bitbucket'* ]]; then
    sx::os::browser::open "${full_url//tree/branch}"
  else
    sx::os::browser::open "${full_url}"
  fi
}
