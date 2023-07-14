#!/usr/bin/env bash

function sx::nerdctl::check_requirements() {
  sx::require_supported_os
  sx::require 'nerdctl'
}

function sx::nerdctl::containers() {
  nerdctl container ls \
    --format='{{.ID}},{{.Names}},{{.Image}},{{.Status}}' \
    "${@}" \
    | column -t -s ','
}

function sx::nerdctl::running_containers() {
  sx::nerdctl::containers \
    --filter 'status=running' \
    --filter 'status=pausing'
}

function sx::nerdctl::all_containers() {
  sx::nerdctl::containers '--all'
}

function sx::nerdctl::has_container() {
  local -r container_id="${1}"

  if [ -z "${container_id}" ]; then
    sx::log::fatal 'A container id is required as first argument'
  fi

  sx::nerdctl::all_containers | grep -q "${container_id}"
}

function sx::nerdctl::container_name() {
  local -r container_id="${1}"

  if [ -z "${container_id}" ]; then
    sx::log::fatal 'A container id is required as first argument'
  fi

  sx::nerdctl::all_containers \
    | grep "${container_id}" \
    | awk '{ print $2 }'
}

function sx::nerdctl::list_resources() {
  nerdctl container ls \
    --all \
    --format 'container {{.ID}} {{.Names}}'

  nerdctl image ls \
    --format='image {{.ID}} {{.Repository}}:{{.Tag}}'

  nerdctl volume ls \
    --format 'volume {{.Name}}'

  nerdctl network ls \
    --format 'network {{.ID}} {{.Name}}'
}

function sx::nerdctl::list_inspectable_resources() {
  nerdctl container ls \
    --all \
    --format 'container {{.ID}} {{.Names}}'

  nerdctl image ls \
    --format='image {{.ID}} {{.Repository}}:{{.Tag}}'
}
