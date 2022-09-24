#!/usr/bin/env bash

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

  pg_dump \
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

  pg_restore \
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

  psql "${db_uri}"
}
