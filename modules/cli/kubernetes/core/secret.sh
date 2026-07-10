#!/usr/bin/env bash

function sx::k8s::secret() {
  sx::k8s::check_requirements
  sx::k8s::ensure_api_access
  sx::require 'base64'

  local -r query="${1:-}"
  local -r exact="${2:-}"
  local -r namespace="${3:-}"
  local -r all_namespaces="${4:-false}"
  local -r list="${5:-false}"
  local -r key="${6:-}"

  if [ -n "${exact}" ]; then
    local -r ns="${namespace:-$(sx::k8s::current_namespace)}"

    sx::k8s_command::secret "${ns}" "${exact}" "${key}"
  elif ${list}; then
    sx::k8s_command::secret::list "${query}" "${namespace}" "${all_namespaces}" true
  elif sx::os::is_command_available 'fzf'; then
    local -r options="$(
      sx::k8s_command::secret::list "${query}" "${namespace}" "${all_namespaces}" true
    )"

    if [ -z "${options}" ]; then
      sx::log::fatal 'No resources found'
    fi

    # shellcheck disable=SC2086  # quote this to prevent word splitting
    local -r selected="$(echo -e "${options}" | fzf --header-lines 1 ${SX_FZF_ARGS})"

    if [ -n "${selected}" ]; then
      local -r ns="$(echo "${selected}" | awk '{ print $1 }')"
      local -r name="$(echo "${selected}" | awk '{ print $2 }')"

      sx::k8s_command::secret "${ns}" "${name}" "${key}"
    fi
  else
    export PS3=$'\n''Please, choose the resource: '$'\n'

    local options
    readarray -t options < <(
      sx::k8s_command::secret::list "${query}" "${namespace}" "${all_namespaces}"
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
      local -r name="$(echo "${selected}" | awk '{ print $2 }')"

      sx::k8s_command::secret "${ns}" "${name}" "${key}"
      break
    done
  fi
}

function sx::k8s_command::secret::list() {
  local -r query="${1:-}"
  local -r namespace="${2:-}"
  local -r all_namespaces="${3:-false}"
  local -r print_header="${4:-false}"

  if ${all_namespaces}; then
    local -r flags='--all-namespaces'
  elif [ -n "${namespace}" ]; then
    local -r flags="--namespace ${namespace}"
  else
    local -r flags=''
  fi

  if [ -n "${query}" ]; then
    local -r query_pattern="${query}"
  else
    local -r query_pattern='.*'
  fi

  # shellcheck disable=SC2016  # Expressions don't expand in single quotes, use double quotes for that
  local -r template='
  {{range .items}}
    {{.metadata.namespace}}{{","}}{{.metadata.name}}{{","}}{{.type}}{{","}}{{.metadata.creationTimestamp}}{{"\n"}}
  {{end}}'

  local -r now="$(date '+%s')"

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  local -r result="$(
    sx::k8s::cli get secrets \
      ${flags} \
      --output='go-template' \
      --template="$(sx::k8s::clear_template "${template}")" 2>/dev/null \
      | sort -u \
      | grep -E "${query_pattern}" 2>/dev/null \
      | while IFS=',' read -r secret_namespace secret_name secret_type created_at; do
        local secret_age="$(sx::k8s::age "${created_at}" "${now}")"

        echo "${secret_namespace},${secret_name},${secret_type},${secret_age}"
      done
  )"

  if [ -z "${result}" ]; then
    echo
  elif ${print_header}; then
    local -r header='NAMESPACE,NAME,TYPE,AGE'
    echo -e "${header}\n${result}" | column -t -s ','
  else
    echo -e "${result}" | column -t -s ','
  fi
}

function sx::k8s_command::secret() {
  local -r ns="${1:-}"
  local -r name="${2:-}"
  local -r key="${3:-}"

  # shellcheck disable=SC2016  # Expressions don't expand in single quotes, use double quotes for that
  local -r template='
  {{range $k, $v := .data}}
    {{$k}}{{"\t"}}{{$v}}{{"\n"}}
  {{end}}'

  local -r data="$(
    sx::k8s::cli get secret "${name}" \
      --namespace "${ns}" \
      --output='go-template' \
      --template="$(sx::k8s::clear_template "${template}")"
  )"

  if [ -z "${data}" ]; then
    sx::log::fatal "No data found in secret \"${ns}/${name}\""
  fi

  if [ -n "${key}" ]; then
    while IFS=$'\t' read -r secret_key encoded_value; do
      if [ "${secret_key}" = "${key}" ]; then
        printf '%s' "${encoded_value}" | base64 --decode
        return
      fi
    done <<<"${data}"

    local -r available_keys="$(echo "${data}" | awk '{ print $1 }' | xargs)"
    sx::log::fatal "No such key \"${key}\" in secret \"${ns}/${name}\" (available keys: ${available_keys})"
  else
    sx::log::info "Decoding secret \"${ns}/${name}\"\n"

    local -r result="$(
      echo "${data}" \
        | while IFS=$'\t' read -r secret_key encoded_value; do
          local decoded_value="$(printf '%s' "${encoded_value}" | base64 --decode)"
          decoded_value="${decoded_value//$'\t'/\\t}"
          decoded_value="${decoded_value//$'\n'/\\n}"

          printf '%s\t%s\n' "${secret_key}" "${decoded_value}"
        done
    )"

    local -r header=$'KEY\tVALUE'
    printf '%s\n%s\n' "${header}" "${result}" | column -t -s $'\t'
  fi
}
