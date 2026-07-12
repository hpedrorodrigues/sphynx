#!/usr/bin/env bash

function sx::flow::ls() {
  sx::flow::check_requirements

  local -r name="${1:-}"
  local -r prefix="${2:-}"
  local -r captures="${3:-false}"
  local -r collections="${4:-false}"
  local -r materializations="${5:-false}"
  local -r tests="${6:-false}"
  local -r flows="${7:-false}"

  local flags=''
  if [ -n "${name}" ]; then
    flags+=" --name ${name}"
  fi

  if [ -n "${prefix}" ]; then
    flags+=" --prefix ${prefix}"
  fi

  if ${captures}; then
    flags+=' --captures'
  fi

  if ${collections}; then
    flags+=' --collections'
  fi

  if ${materializations}; then
    flags+=' --materializations'
  fi

  if ${tests}; then
    flags+=' --tests'
  fi

  if ${flows}; then
    flags+=' --flows'
  fi

  if ${flows}; then
    local -r header=$'NAME\tTYPE\tSTATUS\tDISABLED\tUPDATED\tREADS FROM\tWRITES TO'
    local -r selector='[
        .catalogName,
        (.liveSpec.catalogType // "-"),
        (.status.type // "-"),
        (.liveSpec.isDisabled // false | tostring),
        (.liveSpec.updatedAt // "-"),
        ((.liveSpec.readsFrom.edges // []) | map(.node.catalogName) | if length == 0 then "-" else join(",") end),
        ((.liveSpec.writesTo.edges // []) | map(.node.catalogName) | if length == 0 then "-" else join(",") end)
      ] | @tsv'
  else
    local -r header=$'NAME\tTYPE\tSTATUS\tDISABLED\tUPDATED'
    local -r selector='[
        .catalogName,
        (.liveSpec.catalogType // "-"),
        (.status.type // "-"),
        (.liveSpec.isDisabled // false | tostring),
        (.liveSpec.updatedAt // "-")
      ] | @tsv'
  fi

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  local -r result="$(
    sx::flow::cli catalog list ${flags} --output json \
      | jq -r "${selector}" \
      | sort
  )"

  if [ -z "${result}" ]; then
    sx::log::fatal 'No specifications found'
  fi

  printf '%s\n%s\n' "${header}" "${result}" | column -t -s $'\t'
}
