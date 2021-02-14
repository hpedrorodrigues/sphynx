#!/usr/bin/env bash

function sx::k8s::shell() {
  sx::k8s::check_requirements

  local -r query="${1:-}"

  if sx::os::is_command_available 'fzf'; then
    local -r options="$(sx::k8s::nodes "${query}")"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No nodes found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf ${SX_FZF_ARGS})"

    [ -n "${selected}" ] && sx::k8s_command::shell "${selected}"
  else
    export PS3=$'\n''Please, choose the node: '$'\n'

    local options
    readarray -t options < <(sx::k8s::nodes "${query}")

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No nodes found'
    fi

    select selected in "${options[@]}"; do
      sx::k8s_command::shell "${selected}"
      break
    done
  fi
}

function sx::k8s::nodes() {
  local -r query="${1:-}"

  if [ -n "${query}" ]; then
    local -r selector="$(echo "${query}" | sx::string::lowercase)"
  else
    local -r selector='.*'
  fi

  sx::k8s::cli get nodes \
    --output custom-columns=NAME:.metadata.name \
    --no-headers \
    | sx::string::lowercase \
    | grep -E "${selector}" 2>/dev/null
}

function sx::k8s_command::shell() {
  local -r node_name="${1:-}"

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
          "PS1='${SX_KUBERNETES_PS1//\\/\\\\}' exec /bin/bash --login"
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
    --requests 'cpu=25m,memory=25Mi' \
    --limits 'cpu=25m,memory=25Mi' \
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
