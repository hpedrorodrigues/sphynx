#!/usr/bin/env bash

function sx::gcloud::snooze::now() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

# Portable "now + duration" as an RFC3339 timestamp (BSD vs GNU date).
# Accepts <N> with a unit suffix: s, m, h, d, w (defaults to 1h).
function sx::gcloud::snooze::end_time() {
  local -r duration="${1:-1h}"
  local -r amount="${duration%[smhdw]}"
  local -r unit="${duration##*[0-9]}"

  if ! [[ "${amount}" =~ ^[0-9]+$ ]]; then
    sx::log::fatal "Invalid duration \"${duration}\" (use e.g. 30m, 2h, 7d, 1w)"
  fi

  local seconds
  case "${unit}" in
    s) seconds="${amount}" ;;
    m) seconds=$((amount * 60)) ;;
    h) seconds=$((amount * 3600)) ;;
    d) seconds=$((amount * 86400)) ;;
    w) seconds=$((amount * 604800)) ;;
    *) sx::log::fatal "Invalid duration \"${duration}\" (use e.g. 30m, 2h, 7d, 1w)" ;;
  esac

  local -r epoch=$(($(date -u +%s) + seconds))

  if sx::os::is_macos; then
    date -u -r "${epoch}" +%Y-%m-%dT%H:%M:%SZ
  else
    date -u -d "@${epoch}" +%Y-%m-%dT%H:%M:%SZ
  fi
}

# List alert policies (resource name + display name), filtered by the query
# used as a case-insensitive regex. Empty query matches everything.
function sx::gcloud::snooze::search_policies() {
  local -r query="${1:-}"
  local -r project="${2:-}"

  local flags=''
  if [ -n "${project}" ]; then
    flags=" --project ${project}"
  fi

  if [ -n "${query}" ]; then
    local -r query_pattern="${query}"
  else
    local -r query_pattern='.*'
  fi

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  sx::gcloud::cli monitoring policies list \
    --format='value[separator=","](name, displayName)' \
    ${flags} \
    | column -t -s ',' \
    | grep -iE "${query_pattern}" 2>/dev/null
}

function sx::gcloud::snooze::create() {
  sx::gcloud::check_requirements

  local -r query="${1:-}"
  local -r filter="${2:-}"
  local -r duration="${3:-}"
  local -r start="${4:-}"
  local -r end="${5:-}"
  local -r name="${6:-}"
  local -r project="${7:-}"

  local selected
  if sx::os::is_command_available 'fzf'; then
    local -r options="$(sx::gcloud::snooze::search_policies "${query}" "${project}")"
    if [ -z "${options}" ]; then
      sx::log::fatal 'No alert policies found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    selected="$(echo -e "${options}" | fzf ${SX_FZF_ARGS})"
    if [ -z "${selected}" ]; then
      return 0
    fi
  else
    export PS3=$'\n''Please, choose the alert policy: '$'\n'

    local options
    readarray -t options < <(sx::gcloud::snooze::search_policies "${query}" "${project}")
    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No alert policies found'
    fi

    select selected in "${options[@]}"; do
      if [ -z "${selected}" ]; then
        sx::log::err "Invalid option \"${REPLY}\". Please, type the number of the desired option."
        continue
      fi
      break
    done
  fi

  read -r policy_id policy_name <<<"${selected}"

  local start_time end_time
  if [ -n "${duration}" ]; then
    start_time="$(sx::gcloud::snooze::now)"
    end_time="$(sx::gcloud::snooze::end_time "${duration}")"
  else
    start_time="${start}"
    end_time="${end}"
  fi

  local flags=''

  if [ -n "${filter}" ]; then
    flags+=" --criteria-filter=${filter}"
  fi

  if [ -n "${project}" ]; then
    flags+=" --project=${project}"
  fi

  sx::log::info "Creating snooze for policy \"${policy_name}\" (${policy_id}) from ${start_time} to ${end_time}\n"

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  sx::gcloud::cli monitoring snoozes create \
    --criteria-policies="${policy_id}" \
    --display-name="${name}" \
    --start-time="${start_time}" \
    --end-time="${end_time}" \
    ${flags}
}

function sx::gcloud::snooze::list() {
  sx::gcloud::check_requirements
  sx::require 'jq'

  local -r active="${1:-false}"
  local -r project="${2:-}"

  local flags=''
  if [ -n "${project}" ]; then
    flags=" --project ${project}"
  fi

  local row_filter='.'
  if ${active}; then
    row_filter='select((.interval.startTime | fromdateiso8601) <= now and (.interval.endTime | fromdateiso8601) > now)'
  fi

  local -r header=$'ID\tDISPLAY_NAME\tSTART\tEND\tPOLICIES\tFILTER'
  local -r selector="
    .[]
    | ${row_filter}
    | [
        (.name | split(\"/\") | last),
        (.displayName // \"-\"),
        .interval.startTime,
        .interval.endTime,
        ((.criteria.policies // []) | map(split(\"/\") | last) | join(\",\")),
        (.criteria.filter // \"-\")
      ]
    | @tsv"

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  local -r result="$(
    sx::gcloud::cli monitoring snoozes list --format=json ${flags} \
      | jq -r "${selector}" \
      | sort
  )"

  if [ -z "${result}" ]; then
    sx::log::fatal 'No snoozes found'
  fi

  printf '%s\n%s\n' "${header}" "${result}" | column -t -s $'\t'
}
