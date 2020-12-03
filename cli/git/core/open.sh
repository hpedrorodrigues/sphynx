#!/usr/bin/env bash

function sx::git::open() {
  sx::git::check_requirements

  local -r file_path="${1:-.}"

  if [ ! -e "${file_path}" ]; then
    sx::log::fatal "File or directory \"${file_path}\" does not exist..."
  fi

  local -r git_url="$(sx::git::remote::url \
    | sed 's/git@/\/\//g' \
    | sed 's/.git$//' \
    | sed 's/http://g' \
    | sed 's/https://g' \
    | sed 's/ssh://g' \
    | sed 's/:/\//g')"
  local -r git_branch="$(sx::git::current_branch)"
  local -r base_url="http:${git_url}"

  if [ "${file_path}" = '.' ]; then
    local -r full_url="$([ "${git_branch}" = "master" ] || [ "${git_branch}" = "main" ] \
      && echo "${base_url}" \
      || echo "${base_url}/tree/${git_branch}")"
  else
    local -r root="$(git rev-parse --show-toplevel | sed 's/\//\\\//g')"
    local -r full_file_path="$(sx::fs::fullpath "${file_path}")"
    local -r relative_file_path="$(echo "${full_file_path}" | sed "s/${root}\///g")"
    local -r full_url="${base_url}/blob/${git_branch}/${relative_file_path}"
  fi

  if [[ ${full_url} == *'bitbucket'* ]]; then
    sx::os::browser::open "${full_url//tree/branch}"
  else
    sx::os::browser::open "${full_url}"
  fi
}
