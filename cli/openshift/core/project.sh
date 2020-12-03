#!/usr/bin/env bash

function sx::openshift::switch_project() {
  local -r new_project="${1}"

  oc project "${new_project}"
}

function sx::openshift::project() {
  sx::openshift::check_requirements

  local -r show_current_project="${1:-false}"

  if ${show_current_project}; then
    sx::openshift::current_project
  elif sx::os::is_command_available 'fzf'; then
    local -r options="$(sx::openshift::all_projects)"
    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf ${SX_FZF_ARGS})"

    [ -n "${selected}" ] \
      && sx::openshift::switch_project "$(echo "${selected}" | awk '{ print $1 }')"
  else
    export PS3=$'\n''Please, choose the project: '$'\n'

    local options
    mapfile -t options < <(sx::openshift::all_projects)

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No projects found'
    fi

    select selected in "${options[@]}"; do
      sx::openshift::switch_projectt "$(echo "${selected}" | awk '{ print $1 }')"
      break
    done
  fi
}
