#!/usr/bin/env bash

export SX_APPLICATION_NAME="${SX_APPLICATION_NAME:-sphynx-psql}"

function sx::postgresql::dump() {
  sx::persistence::check_requirements
  sx::require 'pg_dump'

  local -r db_uri="${1}"
  if [ -z "${db_uri}" ]; then
    sx::log::fatal 'A database URI is necessary in order to dump the database'
  fi

  local -r file_name="${2}"
  if [ -f "${file_name}" ]; then
    sx::log::fatal "The file named \"${file_name}\" already exists"
  fi

  PGAPPNAME="${SX_APPLICATION_NAME}" pg_dump \
    --dbname "${db_uri}" \
    --blobs \
    --format c \
    --file "${file_name}" \
    --verbose
}

function sx::postgresql::restore() {
  sx::persistence::check_requirements
  sx::require 'pg_restore'

  local -r db_uri="${1}"
  if [ -z "${db_uri}" ]; then
    sx::log::fatal 'A database URI is necessary in order to restore the database'
  fi

  local -r file_name="${2}"
  if ! [ -f "${file_name}" ]; then
    sx::log::fatal "No such file \"${file_name}\""
  fi

  PGAPPNAME="${SX_APPLICATION_NAME}" pg_restore \
    --dbname "${db_uri}" \
    --format c \
    --verbose \
    "${file_name}"
}

function sx::postgresql::connect() {
  sx::persistence::check_requirements
  sx::require 'psql'

  local -r db_uri="${1}"
  if [ -z "${db_uri}" ]; then
    sx::log::fatal 'A database URI is necessary to connect to the database'
  fi

  PGAPPNAME="${SX_APPLICATION_NAME}" psql "${db_uri}"
}

function sx::postgresql::list_connected_pods() {
  sx::persistence::check_requirements
  sx::require 'psql'
  sx::k8s::check_requirements

  local -r db_uri="${1}"
  local -r wide="${2:-false}"
  local -r empty_value='<no value>'
  # It's necessary to ensure commas/quotes/spaces in result rows don't split across columns
  local -r sep=$'\x1f'

  local db_columns="client_addr, datname, usename, NULLIF(application_name, '') AS application_name, pid"
  local result_header="POD${sep}ADDRESS${sep}DATABASE${sep}USER${sep}APPLICATION${sep}PID"
  if ${wide}; then
    db_columns+=", backend_type, query"
    result_header+="${sep}BACKEND TYPE${sep}QUERY"
  fi
  local -r db_query="SELECT ${db_columns} FROM pg_stat_activity ORDER BY datname, usename, application_name;"

  local -r pods="$(
    sx::k8s::cli get pods \
      --all-namespaces \
      --no-headers \
      --output custom-columns=NAME:.metadata.name,ADDRESS:.status.podIP
  )"

  local result="${result_header}"$'\n'
  while IFS='' read -r row; do
    local client_address="${row%%"${sep}"*}"
    local pod_name="$(
      echo "${pods}" \
        | awk -v client_address="${client_address}" '$2 == client_address { print $1; exit }'
    )"
    result+="${pod_name:-${empty_value}}${sep}${row}"$'\n'
  done < <(
    PGAPPNAME="${SX_APPLICATION_NAME}" psql \
      --no-psqlrc \
      --command "${db_query}" \
      --tuples-only \
      --no-align \
      --field-separator="${sep}" \
      --pset="null=${empty_value}" \
      "${db_uri}"
  )

  printf '%s' "${result}" | column -t -s "${sep}"
}
