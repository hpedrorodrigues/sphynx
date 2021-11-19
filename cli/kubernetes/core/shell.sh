#!/usr/bin/env bash

function sx::k8s::shell() {
  sx::k8s::check_requirements
  sx::k8s::ensure_api_access

  local -r query="${1:-}"
  local -r use_ssm="${2:-false}"

  if sx::os::is_command_available 'fzf'; then
    local -r options="$(sx::k8s::nodes "${query}" true)"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No nodes found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf --header-lines 1 ${SX_FZF_ARGS})"

    if [ -n "${selected}" ]; then
      if ${use_ssm}; then
        sx::k8s_command::ssm "${selected}"
      else
        sx::k8s_command::shell "${selected}"
      fi
    fi
  else
    export PS3=$'\n''Please, choose the node: '$'\n'

    local options
    readarray -t options < <(sx::k8s::nodes "${query}")

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No nodes found'
    fi

    select selected in "${options[@]}"; do
      if ${use_ssm}; then
        sx::k8s_command::ssm "${selected}"
      else
        sx::k8s_command::shell "${selected}"
      fi
      break
    done
  fi
}

function sx::k8s_command::ssm() {
  sx::require 'aws' 'aws-cli'

  local -r node_name="$(echo "${1}" | awk '{ print $1 }')"

  local -r provider_id="$(
    kubectl get nodes \
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

  sx::log::info "Opening shell in node \"${node_name}\" using \"/bin/bash\"\n"

  sx::k8s::cli run "${pod_name}" \
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

  local -r remaining_pod="$(
    sx::k8s::cli get pods \
      --namespace "${namespace}" \
      --selector "app=${container_name}" 2>/dev/null
  )"

  if [ -n "${remaining_pod}" ]; then
    sx::log::warn "Deleting remaining pod ${pod_name}"
    sx::k8s::cli delete pod "${pod_name}" --namespace "${namespace}"
  fi
}
