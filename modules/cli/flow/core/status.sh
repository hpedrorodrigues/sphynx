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

  if sx::os::is_command_available 'fzf'; then
    local -r options="$(sx::flow::specs "${query}" true "${type_flags}")"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No specifications found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf --header-lines 1 ${SX_FZF_ARGS})"

    if [ -n "${selected}" ]; then
      local -r spec="$(echo "${selected}" | awk '{ print $1 }')"

      sx::flow_command::status "${spec}" "${connected}"
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

      sx::flow_command::status "${spec}" "${connected}"
      break
    done
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
