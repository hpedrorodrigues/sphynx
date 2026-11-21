#!/usr/bin/env bash

function sx::flow::history() {
  sx::flow::check_requirements

  local -r query="${1:-}"
  local -r captures="${2:-false}"
  local -r collections="${3:-false}"
  local -r materializations="${4:-false}"
  local -r tests="${5:-false}"

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

    sx::flow_command::history "${spec}"
  fi
}

function sx::flow_command::history() {
  local -r name="${1}"

  local -r result="$(
    sx::flow::cli catalog history --name "${name}" --output json \
      | jq -sr 'sort_by(.publication.publishedAt) | reverse | .[] | [
          (.publication.publicationId // "-"),
          (.publication.publishedAt // "-"),
          (.publication.userEmail // "-"),
          (.publication.detail // "-")
        ] | @tsv'
  )"

  if [ -z "${result}" ]; then
    sx::log::fatal "No publication history found for \"${name}\""
  fi

  printf 'PUBLICATION ID\tPUBLISHED\tUSER\tDETAIL\n%s\n' "${result}" | column -t -s $'\t'
}
