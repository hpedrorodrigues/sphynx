#!/usr/bin/env bash

function sx::flow::logs() {
  sx::flow::check_requirements

  local -r query="${1:-}"
  local -r follow="${2:-false}"
  local -r since="${3:-}"
  local -r not_before="${4:-}"
  local -r extra_flags="${5:-}"
  local -r captures="${6:-false}"
  local -r derivations="${7:-false}"
  local -r materializations="${8:-false}"

  local task_type=''
  if ${captures}; then
    task_type='capture'
  elif ${derivations}; then
    task_type='derivation'
  elif ${materializations}; then
    task_type='materialization'
  fi

  local flags=''
  if ${follow}; then
    flags+=' --follow'
  fi

  if [ -n "${since}" ]; then
    flags+=" --since ${since}"
  fi

  if [ -n "${not_before}" ]; then
    flags+=" --not-before ${not_before}"
  fi

  local -r options="$(sx::flow::tasks "${query}" true "${task_type}")"

  if [ -z "${options}" ]; then
    sx::log::fatal 'No tasks found'
  fi

  local -r selected="$(sx::select_one 'Please, choose the task' 1 <<<"${options}")"

  if [ -n "${selected}" ]; then
    local -r task="$(echo "${selected}" | awk '{ print $1 }')"

    sx::flow_command::logs "${task}" "${flags}" "${extra_flags}"
  fi
}

function sx::flow_command::logs() {
  local -r task="${1}"
  local -r flags="${2:-}"
  local -r extra_flags="${3:-}"

  sx::log::info "Reading logs from task \"${task}\"\n"

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  sx::flow::cli logs --task "${task}" ${flags} ${extra_flags}
}
