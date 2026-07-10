#!/usr/bin/env bash

function sx::flux::status() {
  sx::flux::check_requirements

  local -r query="${1:-}"
  local -r kind="${2:-}"
  local -r namespace="${3:-}"
  local -r all_namespaces="${4:-false}"

  if [ -n "${kind}" ]; then
    local -r resources="$(echo "${kind}" | sx::string::lowercase)"
  else
    local -r resources="${SX_FLUX_RESOURCES}"
  fi

  local -r result="$(
    sx::flux_command::status::table "${resources}" "${query}" "${namespace}" "${all_namespaces}"
  )"

  if [ -z "${result}" ]; then
    sx::log::fatal 'No resources found'
  fi

  local -r header=$'NAMESPACE\tKIND\tNAME\tREADY\tSUSPENDED\tMESSAGE'
  printf '%s\n%s\n' "${header}" "${result}" | column -t -s $'\t'
}

function sx::flux::status::watch() {
  sx::flux::check_requirements

  local -r interval="${1:-2}"
  local -r query="${2:-}"
  local -r kind="${3:-}"
  local -r namespace="${4:-}"
  local -r all_namespaces="${5:-false}"

  local args=''
  if [ -n "${kind}" ]; then
    args+=" --kind ${kind}"
  fi

  if ${all_namespaces}; then
    args+=' --all-namespaces'
  elif [ -n "${namespace}" ]; then
    args+=" --namespace ${namespace}"
  fi

  if [ -n "${query}" ]; then
    args+=" ${query}"
  fi

  if sx::os::is_command_available "${SPHYNX_EXEC_NAME}"; then
    local -r sphynx_command="${SPHYNX_EXEC_NAME}"
  else
    local -r sphynx_command="${SPHYNX_EXEC}"
  fi

  # shellcheck disable=SC2086  # intentional word splitting on flags
  sx::os::watcher "${interval}" "${sphynx_command}" flux status ${args}
}

function sx::flux_command::status::table() {
  local -r resources="${1}"
  local -r query="${2:-}"
  local -r namespace="${3:-}"
  local -r all_namespaces="${4:-false}"

  if ${all_namespaces}; then
    local -r flags='--all-namespaces'
  elif [ -n "${namespace}" ]; then
    local -r flags="--namespace ${namespace}"
  else
    local -r flags=''
  fi

  if [ -n "${query}" ]; then
    local -r selector="${query}"
  else
    local -r selector='.*'
  fi

  # shellcheck disable=SC2016  # Expressions don't expand in single quotes, use double quotes for that
  local -r template='
  {{range .items}}
    {{$ready := "Unknown"}}
    {{$message := "-"}}
    {{range .status.conditions}}
      {{if eq .type "Ready"}}
        {{$ready = .status}}
        {{if .message}}
          {{$message = .message}}
        {{end}}
      {{end}}
    {{end}}
    {{.metadata.namespace}}{{"\t"}}
    {{.kind}}{{"\t"}}
    {{.metadata.name}}{{"\t"}}
    {{$ready}}{{"\t"}}
    {{if .spec.suspend}}True{{else}}False{{end}}{{"\t"}}
    {{$message}}{{"\n"}}
  {{end}}'

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  kubectl get "${resources}" \
    ${flags} \
    --output go-template \
    --template="$(sx::flux::clear_template "${template}")" 2>/dev/null \
    | grep -iE "${selector}" 2>/dev/null \
    | while IFS=$'\t' read -r row_ns row_kind row_name row_ready row_suspended row_message; do
      # Multi-line condition messages produce continuation lines without the
      # leading columns; skip them (the message is truncated at its first line)
      if [ -z "${row_name}" ]; then
        continue
      fi

      row_message="${row_message//$'\t'/ }"

      printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
        "${row_ns}" "${row_kind}" "${row_name}" "${row_ready}" "${row_suspended}" "${row_message:--}"
    done
}
