#!/usr/bin/env bash

function sx::docker::check_requirements() {
  sx::require_supported_os
  sx::require 'docker'
  sx::docker::ensure_docker_daemon_running
}

# https://docs.docker.com/config/daemon/#check-whether-docker-is-running
function sx::docker::is_docker_daemon_running() {
  docker info &>/dev/null
}

function sx::docker::ensure_docker_daemon_running() {
  if ! sx::docker::is_docker_daemon_running; then
    sx::log::fatal 'Docker daemon is not running!'
  fi
}

function sx::docker::containers() {
  local -r template='table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}'

  docker container ls --format="${template}" "${@}" | tail -n +2
}

function sx::docker::running_containers() {
  sx::docker::containers \
    --filter 'status=running' \
    --filter 'status=restarting' \
    --filter 'status=removing'
}

function sx::docker::all_containers() {
  sx::docker::containers '--all'
}

function sx::docker::has_container() {
  local -r container_id="${1}"

  if [ -z "${container_id}" ]; then
    sx::log::fatal 'A container id is required as first argument'
  fi

  sx::docker::all_containers | grep -q "${container_id}"
}

function sx::docker::container_name() {
  local -r container_id="${1}"

  if [ -z "${container_id}" ]; then
    sx::log::fatal 'A container id is required as first argument'
  fi

  sx::docker::all_containers \
    | grep "${container_id}" \
    | awk '{ print $2 }'
}

function sx::docker::list_resources() {
  docker container ls \
    --all \
    --format 'container {{.ID}} {{.Names}}'

  docker images \
    --format='image {{.ID}} {{.Repository}}:{{.Tag}}'

  docker volume ls \
    --format 'volume {{.Name}}'

  docker network ls \
    --filter 'type=custom' \
    --format 'network {{.ID}} {{.Name}}'
}
