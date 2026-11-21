#!/usr/bin/env bash

function sx::flow::status() {
  sx::flow::check_requirements

  local -r query="${1:-}"
  local -r connected="${2:-false}"
  local -r captures="${3:-false}"
  local -r collections="${4:-false}"
  local -r materializations="${5:-false}"
  local -r tests="${6:-false}"

  local type_flags=''
  if ${captures}; then
    type_flags=' --captures'
  elif ${collections}; then
    type_flags=' --collections'
  elif ${materializations}; then
    type_flags=' --materializations'
  elif ${tests}; then
    type_flags=' --tests'
  fi

  local -r options="$(sx::flow::specs "${query}" true "${type_flags}")"

  if [ -z "${options}" ]; then
    sx::log::fatal 'No specifications found'
  fi

  local -r selected="$(sx::select_one 'Please, choose the specification' 1 <<<"${options}")"

  if [ -n "${selected}" ]; then
    local -r spec="$(echo "${selected}" | awk '{ print $1 }')"

    sx::flow_command::status "${spec}" "${connected}"
  fi
}

function sx::flow_command::status() {
  local -r name="${1}"
  local -r connected="${2:-false}"

  local flags=''
  if ${connected}; then
    flags+=' --connected'
  fi

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  local -r result="$(
    sx::flow::cli catalog status "${name}" ${flags} --output json \
      | jq -r '[
          (.catalogName // "-"),
          (.catalogType // "-"),
          (.status.type // "-"),
          (.status.summary // "-"),
          (.liveSpecUpdatedAt // "-")
        ] | @tsv'
  )"

  if [ -z "${result}" ]; then
    sx::log::fatal "No status found for \"${name}\""
  fi

  printf 'NAME\tTYPE\tSTATUS\tSUMMARY\tUPDATED\n%s\n' "${result}" | column -t -s $'\t'
}
