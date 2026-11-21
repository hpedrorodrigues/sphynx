#!/usr/bin/env bash

function sx::k8s::shell() {
  sx::k8s::check_requirements

  local -r query="${1:-}"
  local -r use_ssm="${2:-false}"
  local -r context="${3:-}"
  local -r selector="${4:-}"

  sx::k8s::validate_context "${context}"
  sx::k8s::ensure_api_access "${context}"

  local -r options="$(sx::k8s::nodes "${query}" true "${context}" "${selector}")"

  if [ -z "${options}" ]; then
    sx::log::fatal 'No nodes found'
  fi

  local -r selected="$(sx::select_one 'Please, choose the node' 1 <<<"${options}")"

  if [ -n "${selected}" ]; then
    if ${use_ssm}; then
      sx::k8s_command::ssm "${selected}" "${context}"
    else
      sx::k8s_command::shell "${selected}" "${context}"
    fi
  fi
}

function sx::k8s_command::ssm() {
  sx::require 'aws' 'aws-cli'

  local -r node_name="$(echo "${1}" | awk '{ print $1 }')"
  local -r context="${2:-}"

  local -r context_flags="$(sx::k8s::context_flags "${context}")"

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  local -r provider_id="$(
    sx::k8s::cli ${context_flags} get nodes \
      --no-headers \
      --output 'custom-columns=NAME:.metadata.name,PROVIDER_ID:.spec.providerID' \
      | grep "${node_name}" \
      | awk '{ print $2 }'
  )"

  local -r instance_id="$(echo "${provider_id}" | cut -d '/' -f 5)"
  local -r region="$(echo "${provider_id}" | cut -d '/' -f 4 | sed 's/.\{1\}$//')"

  sx::log::info "Opening shell in node \"${node_name}\" (${instance_id} - ${region}) using AWS SSM Agent"

  aws ssm start-session \
    --target "${instance_id}" \
    --region "${region}"
}

function sx::k8s_command::shell() {
  local -r node_name="$(echo "${1}" | awk '{ print $1 }')"
  local -r context="${2:-}"

  local -r context_flags="$(sx::k8s::context_flags "${context}")"

  local -r image_name='alpine'
  local -r container_name='sphynx-shell'
  local -r namespace='default'

  local -r pod_hash="$(uuidgen | cut -d '-' -f 1 | tr '[:upper:]' '[:lower:]')"
  local -r pod_name="${container_name}-${pod_hash}"
  local -r overrides="$(
    cat <<EOF
{
  "spec": {
    "nodeName": "${node_name}",
    "hostPID": true,
    "containers": [
      {
        "securityContext": {
          "privileged": true
        },
        "image": "${image_name}",
        "name": "${container_name}",
        "stdin": true,
        "stdinOnce": true,
        "tty": true,
        "command": [
          "nsenter",
          "--target",
          "1",
          "--mount",
          "--uts",
          "--ipc",
          "--net",
          "--pid",
          "--",
          "/bin/bash",
          "-c",
          "PS1='${SX_PS1//\\/\\\\}' exec /bin/bash --login"
        ]
      }
    ]
  }
}
EOF
  )"

  sx::log::info "Opening shell in node \"${node_name}\" using \"/bin/bash\".\n"
  sx::log::info "If you don't see a command prompt, try pressing enter."

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  sx::k8s::cli ${context_flags} run "${pod_name}" \
    --rm \
    --stdin \
    --tty \
    --image "${image_name}" \
    --overrides="${overrides}" \
    --namespace "${namespace}" \
    --image-pull-policy 'Always' \
    --restart 'Never' \
    --labels "app=${container_name}" \
    --env 'SOURCE=sphynx' \
    --quiet \
    --grace-period '1'

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  local -r remaining_pod="$(
    sx::k8s::cli ${context_flags} get pods \
      --namespace "${namespace}" \
      --selector "app=${container_name}" 2>/dev/null
  )"

  if [ -n "${remaining_pod}" ]; then
    sx::log::warn "Deleting remaining pod ${pod_name}"
    # shellcheck disable=SC2086  # quote this to prevent word splitting
    sx::k8s::cli ${context_flags} delete pod "${pod_name}" --namespace "${namespace}"
  fi
}
