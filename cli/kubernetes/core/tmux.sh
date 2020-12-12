#!/usr/bin/env bash

export SX_TMUX_SESSION_NAME='kmux'

function sx::k8s::tmux::check_requirements() {
  sx::k8s::check_requirements
  sx::library::tmux::check_requirements
}

function sx::k8s::tmux() {
  sx::k8s::tmux::check_requirements

  local -r query="${1:-}"
  local -r namespace="${2:-}"
  local -r pod="${3:-}"
  local -r container="${4:-}"
  local -r all_namespaces="${5:-false}"

  if [ -n "${namespace}" ] && [ -n "${pod}" ] && [ -n "${container}" ]; then
    sx::k8s_command::tmux "${namespace}" "${pod}" "${container}"
  elif sx::os::is_command_available 'fzf'; then
    local -r options="$(
      sx::k8s::running_pods "${query}" "${namespace}" "${all_namespaces}"
    )"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No running pods found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf ${SX_FZF_ARGS})"

    if [ -n "${selected}" ]; then
      local -r ns="$(echo "${selected}" | awk '{ print $1 }')"
      local -r name="$(echo "${selected}" | awk '{ print $2 }')"
      local -r container_name="$(echo "${selected}" | awk '{ print $3 }')"

      sx::k8s_command::tmux "${ns}" "${name}" "${container_name}"
    fi
  else
    export PS3=$'\n''Please, choose the pod: '$'\n'

    local options
    mapfile -t options < <(
      sx::k8s::running_pods "${query}" "${namespace}" "${all_namespaces}"
    )

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No running pods found'
    fi

    select selected in "${options[@]}"; do
      local -r ns="$(echo "${selected}" | awk '{ print $1 }')"
      local -r name="$(echo "${selected}" | awk '{ print $2 }')"
      local -r container_name="$(echo "${selected}" | awk '{ print $3 }')"

      sx::k8s_command::tmux "${ns}" "${name}" "${container_name}"
      break
    done
  fi
}

function sx::k8s_command::tmux() {
  local -r ns="${1}"
  local -r name="${2}"
  local -r container="${3}"

  if sx::library::tmux::is_running_session; then
    local -r session_name="$(sx::library::tmux::current_session)"
  elif sx::library::tmux::has_session "${SX_TMUX_SESSION_NAME}"; then
    local -r session_name="${SX_TMUX_SESSION_NAME}"
  else
    local -r session_name="${SX_TMUX_SESSION_NAME}"
    sx::library::tmux::new_detached_session "${session_name}"
  fi

  sx::library::tmux::new_window \
    "${session_name}" \
    "${name}/${container}" \
    "${SPHYNX_EXEC} kubernetes logs --namespace '${ns}' --pod '${name}' --container '${container}'"

  sx::library::tmux::new_vertical_pane \
    "${session_name}" \
    "${SPHYNX_EXEC} kubernetes exec --namespace '${ns}' --pod '${name}' --container '${container}'"

  sx::library::tmux::resize_current_pane_down '10'

  sx::library::tmux::force_attach_session "${session_name}"
}
