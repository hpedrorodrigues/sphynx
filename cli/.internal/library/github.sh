#!/usr/bin/env bash

export GITHUB_API_URL='https://api.github.com/'
export GITHUB_BROWSER_API_URL='https://github.com/'
export GITHUB_CONTENT_API_URL='https://raw.githubusercontent.com/'

function sx::github::api() {
  local -r parameters="${*//${GITHUB_API_URL}/}"

  curl \
    --silent \
    --location \
    --header "Authorization: token ${GITHUB_TOKEN}" \
    --header "Accept: application/vnd.github.v3+json" \
    "${GITHUB_API_URL}${parameters}"
}

function sx::github::browser_api() {
  local -r parameters="${*//${GITHUB_BROWSER_API_URL}/}"

  curl \
    --silent \
    --location \
    --header "Authorization: token ${GITHUB_TOKEN}" \
    --header "Accept: application/vnd.github.v3+json" \
    "${GITHUB_BROWSER_API_URL}${parameters}"
}

function sx::github::content_api() {
  local -r parameters="${*//${GITHUB_CONTENT_API_URL}/}"

  curl \
    --silent \
    --location \
    --header "Authorization: token ${GITHUB_TOKEN}" \
    "${GITHUB_CONTENT_API_URL}${parameters}"
}

function sx::github::detect_api() {
  local -r full_url="${1:-}"

  if [ -z "${full_url}" ]; then
    sx::log::fatal 'This function needs an URL as first argument'
  fi

  if [[ "${full_url}" == "${GITHUB_API_URL}"* ]]; then
    sx::github::api "${@}"
  elif [[ "${full_url}" == "${GITHUB_BROWSER_API_URL}"* ]]; then
    sx::github::browser_api "${@}"
  elif [[ "${full_url}" == "${GITHUB_CONTENT_API_URL}"* ]]; then
    sx::github::content_api "${@}"
  else
    sx::log::fatal 'Cannot determine the Github API'
  fi
}
