#!/usr/bin/env bash

readonly min_port_number='2000'
readonly max_port_number='65535'
readonly max_retry_attempts='10'
readonly max_retry_backoff_seconds='30'

function sx::k8s::port_forward() {
  sx::k8s::check_requirements

  local -r query="${1:-}"
  local -r selector="${2:-}"
  local -r namespace="${3:-}"
  local -r all_namespaces="${4:-false}"
  local -r random_port="${5:-false}"
  local -r user_port="${6:-}"
  local -r retry="${7:-false}"
  local -r context="${8:-}"

  sx::k8s::validate_context "${context}"
  sx::k8s::ensure_api_access "${context}"

  if [ -n "${user_port}" ] \
    && { [ "${user_port}" -lt "${min_port_number}" ] || [ "${user_port}" -gt "${max_port_number}" ]; }; then
    sx::log::fatal "Invalid port provided: \"${user_port}\". Valid range \"${min_port_number}..${max_port_number}\"."
  fi

  if sx::os::is_command_available 'fzf'; then
    local -r options="$(
      sx::k8s::resources_and_ports "${query}" "${selector}" "${namespace}" "${all_namespaces}" "${context}"
    )"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No resources found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf ${SX_FZF_ARGS})"

    if [ -n "${selected}" ]; then
      local -r ns="$(echo "${selected}" | awk '{ print $1 }')"
      local -r kind="$(echo "${selected}" | awk '{ print $2 }')"
      local -r name="$(echo "${selected}" | awk '{ print $3 }')"
      local -r port="$(echo "${selected}" | awk '{ print $4 }')"

      sx::k8s_command::port_forward \
        "${ns}" \
        "${kind}" \
        "${name}" \
        "${port}" \
        "${random_port}" \
        "${user_port}" \
        "${retry}" \
        "${context}"
    fi
  else
    export PS3=$'\n''Please, choose the resource: '$'\n'

    local options
    readarray -t options < <(
      sx::k8s::resources_and_ports "${query}" "${selector}" "${namespace}" "${all_namespaces}" "${context}"
    )

    if [ "${#options[@]}" -eq 0 ]; then
      sx::log::fatal 'No resources found'
    fi

    select selected in "${options[@]}"; do
      if [ -z "${selected}" ]; then
        sx::log::err "Invalid option \"${REPLY}\". Please, type the number of the desired option."
        continue
      fi

      local -r ns="$(echo "${selected}" | awk '{ print $1 }')"
      local -r kind="$(echo "${selected}" | awk '{ print $2 }')"
      local -r name="$(echo "${selected}" | awk '{ print $3 }')"
      local -r port="$(echo "${selected}" | awk '{ print $4 }')"

      sx::k8s_command::port_forward \
        "${ns}" \
        "${kind}" \
        "${name}" \
        "${port}" \
        "${random_port}" \
        "${user_port}" \
        "${retry}" \
        "${context}"
      break
    done
  fi
}

function sx::k8s::resources_and_ports() {
  local -r query="${1:-}"
  local -r selector="${2:-}"
  local -r namespace="${3:-}"
  local -r all_namespaces="${4:-false}"
  local -r context="${5:-}"

  if ${all_namespaces}; then
    local flags='--all-namespaces'
  elif [ -n "${namespace}" ]; then
    local flags="--namespace ${namespace}"
  else
    local flags=''
  fi

  if [ -n "${selector}" ]; then
    flags+=" --selector ${selector}"
  fi

  if [ -n "${context}" ]; then
    flags+=" --context ${context}"
  fi

  if [ -n "${query}" ]; then
    local -r query_pattern="${query}"
  else
    local -r query_pattern='.*'
  fi

  # shellcheck disable=SC2016  # expressions don't expand in single quotes
  local -r pods_template='
  {{range .items}}
    {{$namespace := .metadata.namespace}}
    {{$name := .metadata.name}}
    {{$kind := .kind}}
    {{range .spec.containers}}
      {{range .ports}}
        {{$namespace}}{{","}}{{$kind}}{{","}}{{$name}}{{","}}{{.containerPort}}{{"\n"}}
      {{end}}
    {{end}}
    {{range .spec.initContainers}}
      {{if eq .restartPolicy "Always"}}
        {{range .ports}}
          {{$namespace}}{{","}}{{$kind}}{{","}}{{$name}}{{","}}{{.containerPort}}{{"\n"}}
        {{end}}
      {{end}}
    {{end}}
  {{end}}'
  # shellcheck disable=SC2016  # expressions don't expand in single quotes
  local -r services_template='
  {{range .items}}
    {{$namespace := .metadata.namespace}}
    {{$name := .metadata.name}}
    {{$kind := .kind}}
    {{range .spec.ports}}
      {{$namespace}}{{","}}{{$kind}}{{","}}{{$name}}{{","}}{{.port}}{{"\n"}}
    {{end}}
  {{end}}'
  # shellcheck disable=SC2016  # expressions don't expand in single quotes
  local -r deployments_template='
  {{range .items}}
    {{$namespace := .metadata.namespace}}
    {{$name := .metadata.name}}
    {{$kind := .kind}}
    {{range .spec.template.spec.containers}}
      {{range .ports}}
        {{$namespace}}{{","}}{{$kind}}{{","}}{{$name}}{{","}}{{.containerPort}}{{"\n"}}
      {{end}}
    {{end}}
  {{end}}'

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  local -r output="$(
    sx::k8s::cli get services \
      ${flags} \
      --output go-template \
      --template="$(sx::k8s::clear_template "${services_template}")" &
    sx::k8s::cli get deployments \
      ${flags} \
      --output go-template \
      --template="$(sx::k8s::clear_template "${deployments_template}")" &
    sx::k8s::cli get pods \
      ${flags} \
      --output go-template \
      --template="$(sx::k8s::clear_template "${pods_template}")" &
    wait
  )"

  echo "${output}" \
    | sx::string::lowercase \
    | sort -u \
    | column -t -s ',' \
    | grep -E "${query_pattern}" 2>/dev/null
}

function sx::k8s_command::port_forward() {
  local -r ns="${1:-}"
  local -r kind="${2:-}"
  local -r name="${3:-}"
  local -r port="${4:-}"
  local -r random_port="${5:-false}"
  local -r user_port="${6:-}"
  local -r retry="${7:-false}"
  local -r context="${8:-}"

  if [ -n "${user_port}" ]; then
    local -r local_port="${user_port}"
  elif ${random_port}; then
    local -r local_port="$(shuf -i ${min_port_number}-${max_port_number} -n 1)"
  else
    local -r local_port="${port}"
  fi

  if [ "${kind}" = 'pod' ]; then
    sx::log::info "Port forwarding to pod (${ns}/${name}:${port})\n"
  else
    sx::log::info "Port forwarding to a pod selected by the ${kind} (${ns}/${name})\n"
  fi

  if ${retry}; then
    trap 'sx::log::info "\nNo longer retrying port-forward. Cancelled by user. Bye..."; exit 130' INT

    local -r pinned_context="${context:-$(sx::k8s::current_context)}"
    sx::log::info "Pinned context: \"${pinned_context}\", namespace: \"${ns}\".\n"

    local attempt=1
    local delay=1
    while [ "${attempt}" -le "${max_retry_attempts}" ]; do
      sx::k8s::cli port-forward \
        --context "${pinned_context}" \
        --namespace "${ns}" \
        "${kind}/${name}" "${local_port}:${port}" || true

      attempt=$((attempt + 1))

      if [ "${attempt}" -le "${max_retry_attempts}" ]; then
        sx::log::info "Reconnecting in ${delay}s (attempt ${attempt}/${max_retry_attempts})..."
        sleep "${delay}"
        delay=$((delay * 2))
        if [ "${delay}" -gt "${max_retry_backoff_seconds}" ]; then
          delay="${max_retry_backoff_seconds}"
        fi
      fi
    done
  else
    if [ -n "${context}" ]; then
      local -r context_flags="--context ${context}"
    else
      local -r context_flags=''
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    sx::k8s::cli ${context_flags} port-forward \
      --namespace "${ns}" \
      "${kind}/${name}" "${local_port}:${port}"
  fi
}
