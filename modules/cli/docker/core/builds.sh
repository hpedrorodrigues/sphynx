#!/usr/bin/env bash

function sx::docker::builds::ls() {
  sx::docker::check_requirements
  sx::docker::ensure_buildx_history

  docker buildx history ls
}

function sx::docker::builds::pick() {
  local -r prompt="${1:-Select a build record}"

  local -r options="$(sx::docker::build_records)"

  if [ -z "${options}" ]; then
    sx::log::fatal 'No build records found'
  fi

  if sx::os::is_command_available 'fzf'; then
    # shellcheck disable=SC2086  # quote this to prevent word splitting
    echo -e "${options}" \
      | fzf ${SX_FZF_ARGS} \
      | awk '{ print $1 }'
  else
    export PS3=$'\n'"${prompt}: "$'\n'

    local items
    readarray -t items <<<"${options}"

    select selected in "${items[@]}"; do
      if [ -z "${selected}" ]; then
        sx::log::err "Invalid option \"${REPLY}\". Please, type the number of the desired option."
        continue
      fi

      echo "${selected}" | awk '{ print $1 }'
      break
    done
  fi
}

function sx::docker::builds::inspect() {
  sx::docker::check_requirements
  sx::docker::ensure_buildx_history

  local -r ref="$(sx::docker::builds::pick 'Select a build record to inspect')"

  if [ -n "${ref}" ]; then
    docker buildx history inspect "${ref}"
  fi
}

function sx::docker::builds::logs() {
  sx::docker::check_requirements
  sx::docker::ensure_buildx_history

  local -r ref="$(sx::docker::builds::pick 'Select a build record to show logs')"

  if [ -n "${ref}" ]; then
    docker buildx history logs "${ref}"
  fi
}

function sx::docker::builds::open() {
  sx::docker::check_requirements
  sx::docker::ensure_buildx_history

  local -r ref="$(sx::docker::builds::pick 'Select a build record to open')"

  if [ -n "${ref}" ]; then
    docker buildx history open "${ref}"
  fi
}

function sx::docker::builds::delete() {
  sx::docker::check_requirements
  sx::docker::ensure_buildx_history

  local -r all="${1:-false}"

  if ${all}; then
    if ${SX_CONFIRMATION_REQUIRED:-true}; then
      sx::log::info 'Do you really want to delete all build records? Be careful. [y/n]'
      read -e -r confirmation
    fi

    if ! "${SX_CONFIRMATION_REQUIRED:-true}" \
      || [ "${confirmation:-'n'}" = 'y' ] \
      || [ "${confirmation:-'n'}" = 'yes' ]; then
      docker buildx history rm --all
    fi
  else
    local -r ref="$(sx::docker::builds::pick 'Select a build record to delete')"

    if [ -n "${ref}" ]; then
      if ${SX_CONFIRMATION_REQUIRED:-true}; then
        sx::log::info "Do you really want to delete the build record [${ref}]? Be careful. [y/n]"
        read -e -r confirmation
      fi

      if ! "${SX_CONFIRMATION_REQUIRED:-true}" \
        || [ "${confirmation:-'n'}" = 'y' ] \
        || [ "${confirmation:-'n'}" = 'yes' ]; then
        docker buildx history rm "${ref}"
      fi
    fi
  fi
}
