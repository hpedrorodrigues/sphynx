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
    --format t \
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
    --no-owner \
    --no-privileges \
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

  readonly db_uri="${1}"
  readonly db_query='SELECT client_addr, datname, usename, application_name, pid, backend_type, query FROM pg_stat_activity ORDER BY datname, usename, application_name;'
  readonly empty_value='<no value>'

  readonly pods="$(
    sx::k8s::cli get pods \
      --all-namespaces \
      --no-headers \
      --output custom-columns=NAME:.metadata.name,ADDRESS:.status.podIP
  )"

  local result='POD,ADDRESS,DATABASE,USER,APPLICATION,PID,BACKEND TYPE,QUERY\n'
  while IFS='' read -r csv_row; do
    local truncated_csv_row="${csv_row:0:100}"
    local addr="$(echo "${csv_row}" | awk -F, '{ print $1 }')"
    if [ "${addr}" == '' ]; then
      result+="${empty_value},${truncated_csv_row}\n"
      continue
    fi
    local pod_name="$(echo "${pods}" | grep "${addr}" | awk '{ print $1 }')"

    if [ "${pod_name}" == '' ]; then
      result+="${empty_value},${truncated_csv_row}\n"
    else
      result+="${pod_name},${truncated_csv_row}\n"
    fi
  done < <(
    PGAPPNAME="${SX_APPLICATION_NAME}" psql \
      --command "${db_query}" \
      --tuples-only \
      --no-align \
      --csv \
      "${db_uri}" \
      | sed "s/^,/${empty_value},/" \
      | sed "s/,,/,${empty_value},/g" \
      | sed "s/,,/,${empty_value},/g" \
      | sed "s/,$/,${empty_value}/"
  )

  echo -e "${result}" | column -t -s ','
}
