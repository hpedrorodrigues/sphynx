#!/usr/bin/env bash

function sx::k8s::debug() {
  sx::k8s::check_requirements
  sx::k8s::ensure_api_access

  local -r query="${1:-}"
  local -r selector="${2:-}"
  local -r namespace="${3:-}"
  local -r pod="${4:-}"
  local -r container="${5:-}"
  local -r image="${6:-}"
  local -r all_namespaces="${7:-false}"
  local -r user="${8:-}"
  local -r group="${9:-}"
  local -r restricted="${10:-false}"

  if [ -n "${namespace}" ] && [ -n "${pod}" ] && [ -n "${container}" ] && [ -n "${image}" ]; then
    sx::k8s_command::debug "${namespace}" "${pod}" "${container}" "${image}" "${user}" "${group}" "${restricted}"
  elif sx::os::is_command_available 'fzf'; then
    local -r options="$(
      sx::k8s::running_pods "${query}" "${selector}" "${namespace}" "${all_namespaces}" true
    )"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No running pods found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf --header-lines 1 ${SX_FZF_ARGS})"

    if [ -n "${selected}" ]; then
      local -r ns="$(echo "${selected}" | awk '{ print $1 }')"
      local -r name="$(echo "${selected}" | awk '{ print $2 }')"
      local -r container_name="$(echo "${selected}" | awk '{ print $3 }')"

      sx::k8s_command::debug "${ns}" "${name}" "${container_name}" "${image}" "${user}" "${group}" "${restricted}"
    fi
  else
    export PS3=$'\n''Please, choose the pod: '$'\n'

    local options
    readarray -t options < <(
      sx::k8s::running_pods "${query}" "${selector}" "${namespace}" "${all_namespaces}"
    )

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No running pods found'
    fi

    select selected in "${options[@]}"; do
      local -r ns="$(echo "${selected}" | awk '{ print $1 }')"
      local -r name="$(echo "${selected}" | awk '{ print $2 }')"
      local -r container_name="$(echo "${selected}" | awk '{ print $3 }')"

      sx::k8s_command::debug "${ns}" "${name}" "${container_name}" "${image}" "${user}" "${group}" "${restricted}"
    done
  fi
}

function sx::k8s_command::debug() {
  local -r ns="${1}"
  local -r name="${2}"
  local -r container="${3}"
  local -r image="${4}"
  local -r user="${5:-}"
  local -r group="${6:-}"
  local -r restricted="${7:-false}"

  local -r shell='/bin/bash'
  local -r debugger_container="debugger-$(uuidgen | cut -d '-' -f 1 | tr '[:upper:]' '[:lower:]')"
  local -r custom_profile_path="$(mktemp -t partial_container_spec || echo '/tmp/partial_container_spec.yaml')"

  if ${restricted}; then
    local -r profile='restricted'
  else
    local -r profile='sysadmin'
  fi

  if [ -n "${user}" ]; then
    local -r run_as_user="${user}"
  elif ${restricted}; then
    local -r run_as_user='65532'
  else
    local -r run_as_user='0'
  fi

  if [ -n "${group}" ]; then
    local -r run_as_group="${group}"
  elif ${restricted}; then
    local -r run_as_group='65532'
  else
    local -r run_as_group='0'
  fi

  # https://github.com/kubernetes/enhancements/blob/c68dfb941894fc8859a951fe47a60b2161300b88/keps/sig-cli/4292-kubectl-debug-custom-profile/README.md
  if ${restricted}; then
    cat >"${custom_profile_path}" <<-EOF
    securityContext:
      runAsGroup: ${run_as_group}
      runAsUser: ${run_as_user}
      runAsNonRoot: true
      allowPrivilegeEscalation: false
      capabilities:
        drop:
          - ALL
      seccompProfile:
        type: RuntimeDefault
	EOF
  else
    cat >"${custom_profile_path}" <<-EOF
    securityContext:
      runAsGroup: ${run_as_group}
      runAsUser: ${run_as_user}
      runAsNonRoot: false
	EOF
  fi

  sx::log::info "Now you can execute commands in \"${name}(${container})/${debugger_container}\" using image \"${image}\" with \"${shell}\"\n"

  sx::k8s::cli debug "${name}" \
    --stdin \
    --tty \
    --profile "${profile}" \
    --custom="${custom_profile_path}" \
    --namespace "${ns}" \
    --target "${container}" \
    --image "${image}" \
    --container "${debugger_container}" \
    --quiet \
    -- "${shell}" -c "PS1='\u@\h|${debugger_container}:\w ' exec ${shell}"

  exit "${?}"
}
