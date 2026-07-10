#!/usr/bin/env bash

function sx::gcloud::impersonate() {
  sx::gcloud::check_requirements

  local -r query="${1:-}"
  local -r print_current="${2:-false}"
  local -r clear="${3:-false}"
  local -r project="${4:-}"

  if ${print_current}; then
    local -r current_account="$(sx::gcloud_command::impersonate::current)"

    if [ -z "${current_account}" ]; then
      sx::log::info 'No service account is being impersonated'
    else
      sx::log::info "${current_account}"
    fi
  elif ${clear}; then
    sx::log::info 'Clearing service account impersonation\n'

    sx::gcloud::cli config unset auth/impersonate_service_account
  elif sx::os::is_command_available 'fzf'; then
    local -r options="$(sx::gcloud_command::impersonate::search "${query}" "${project}")"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No service accounts found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf ${SX_FZF_ARGS})"

    [ -n "${selected}" ] && sx::gcloud_command::impersonate::change "${selected}"
  else
    export PS3=$'\n''Please, choose the service account: '$'\n'

    local options
    readarray -t options < <(sx::gcloud_command::impersonate::search "${query}" "${project}")

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No service accounts found'
    fi

    select selected in "${options[@]}"; do
      if [ -z "${selected}" ]; then
        sx::log::err "Invalid option \"${REPLY}\". Please, type the number of the desired option."
        continue
      fi

      sx::gcloud_command::impersonate::change "${selected}"
      break
    done
  fi
}

function sx::gcloud_command::impersonate::current() {
  sx::gcloud::cli config get-value auth/impersonate_service_account 2>/dev/null
}

function sx::gcloud_command::impersonate::search() {
  local -r query="${1:-}"
  local -r project="${2:-}"

  local flags=''
  if [ -n "${project}" ]; then
    flags=" --project ${project}"
  fi

  if [ -n "${query}" ]; then
    local -r selector="$(echo "${query}" | sx::string::lowercase)"
  else
    local -r selector='.*'
  fi

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  local -r accounts="$(
    sx::gcloud::cli iam service-accounts list --format 'value(email)' ${flags} \
      | grep -E "${selector}" 2>/dev/null
  )"

  local -r current_account="$(sx::gcloud_command::impersonate::current)"

  while IFS='' read -r account; do
    if [ -n "${current_account}" ] && [ "${account}" = "${current_account}" ]; then
      sx::color::current_item::echo "${account}"
    else
      echo "${account}"
    fi
  done <<<"${accounts}"
}

function sx::gcloud_command::impersonate::change() {
  local -r account="${1}"

  sx::log::info "Impersonating service account \"${account}\"\n"

  sx::gcloud::cli config set auth/impersonate_service_account "${account}"
}
