#!/usr/bin/env bash

export SX_FLOWCTL="${SX_FLOWCTL:-flowctl}"

function sx::flow::check_requirements() {
  sx::require_supported_os
  sx::require 'flowctl'
  sx::require 'jq'
}

function sx::flow::cli() {
  # shellcheck disable=SC2086  # quote this to prevent word splitting
  ${SX_FLOWCTL} "${@}"
}

# NOTE: flowctl errors (e.g. expired authentication) are intentionally not
# silenced so they reach the user instead of becoming an empty selection
function sx::flow::specs() {
  local -r query="${1:-}"
  local -r print_header="${2:-false}"
  local -r type_flags="${3:-}"

  if [ -n "${query}" ]; then
    local -r query_pattern="${query}"
  else
    local -r query_pattern='.*'
  fi

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  local -r result="$(
    sx::flow::cli catalog list ${type_flags} --output json \
      | jq -r '[.catalogName, (.liveSpec.catalogType // "-"), (.status.type // "-")] | @tsv' \
      | sort -u \
      | grep -E "${query_pattern}" 2>/dev/null
  )"

  if [ -z "${result}" ]; then
    return 0
  fi

  if ${print_header}; then
    printf 'NAME\tTYPE\tSTATUS\n%s\n' "${result}" | column -t -s $'\t'
  else
    printf '%s\n' "${result}" | column -t -s $'\t'
  fi
}

# Tasks are captures, derivations and materializations. A single
# "catalog list --flows" call covers all of them because the flowctl type
# flags are mutually exclusive, and "--flows" populates "readsFrom", which
# identifies derivations (collections that read from other collections)
function sx::flow::tasks() {
  local -r query="${1:-}"
  local -r print_header="${2:-false}"

  if [ -n "${query}" ]; then
    local -r query_pattern="${query}"
  else
    local -r query_pattern='.*'
  fi

  local -r result="$(
    sx::flow::cli catalog list --flows --output json \
      | jq -r '
          select(
            (.liveSpec.catalogType == "capture")
            or (.liveSpec.catalogType == "materialization")
            or (.liveSpec.catalogType == "collection" and .liveSpec.readsFrom != null)
          )
          | [
              .catalogName,
              (if .liveSpec.catalogType == "collection" then "derivation" else .liveSpec.catalogType end),
              (.status.type // "-")
            ]
          | @tsv' \
      | sort -u \
      | grep -E "${query_pattern}" 2>/dev/null
  )"

  if [ -z "${result}" ]; then
    return 0
  fi

  if ${print_header}; then
    printf 'NAME\tTYPE\tSTATUS\n%s\n' "${result}" | column -t -s $'\t'
  else
    printf '%s\n' "${result}" | column -t -s $'\t'
  fi
}
