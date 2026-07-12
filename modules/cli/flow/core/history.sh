#!/usr/bin/env bash

function sx::flow::history() {
  sx::flow::check_requirements

  local -r query="${1:-}"
  local -r models="${2:-false}"
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

  if sx::os::is_command_available 'fzf'; then
    local -r options="$(sx::flow::specs "${query}" true "${type_flags}")"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No specifications found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf --header-lines 1 ${SX_FZF_ARGS})"

    if [ -n "${selected}" ]; then
      local -r spec="$(echo "${selected}" | awk '{ print $1 }')"

      sx::flow_command::history "${spec}" "${models}"
    fi
  else
    export PS3=$'\n''Please, choose the specification: '$'\n'

    local options
    readarray -t options < <(
      sx::flow::specs "${query}" false "${type_flags}"
    )

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No specifications found'
    fi

    select selected in "${options[@]}"; do
      if [ -z "${selected}" ]; then
        sx::log::err "Invalid option \"${REPLY}\". Please, type the number of the desired option."
        continue
      fi

      local -r spec="$(echo "${selected}" | awk '{ print $1 }')"

      sx::flow_command::history "${spec}" "${models}"
      break
    done
  fi
}

function sx::flow_command::history() {
  local -r name="${1}"
  local -r models="${2:-false}"

  if ${models}; then
    # "--models" requires a JSON or YAML output
    sx::flow::cli catalog history --name "${name}" --models --output json \
      | jq -sc 'sort_by(.publication.publishedAt) | reverse | .[]'
    return
  fi

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
