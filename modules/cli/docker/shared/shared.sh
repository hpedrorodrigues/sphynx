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

  if sx::docker::has_buildx_history; then
    docker buildx history ls \
      --format 'build {{.Ref}} {{.Name}}' 2>/dev/null
  fi
}

function sx::docker::has_buildx_history() {
  docker buildx history --help &>/dev/null
}

function sx::docker::ensure_buildx_history() {
  if ! sx::docker::has_buildx_history; then
    sx::log::fatal '"docker buildx history" is not available (requires a recent Docker / buildx)'
  fi
}

function sx::docker::build_records() {
  local -r template='{{.Ref}} {{.Name}} ({{.Status}})'

  docker buildx history ls --format "${template}" 2>/dev/null
}

# Prints one "<builder> <status>" line per buildx builder. A builder is
# "running" only when all its nodes are: buildx cannot prune a builder that
# has a node whose driver is not running.
function sx::docker::buildx_builders() {
  local -r template='{{.Builder.Name}}|{{.Status}}|{{.Error}}'

  local builder status error
  local -A statuses=()

  while IFS='|' read -r builder status error; do
    if [ -z "${status}" ] && [ -n "${error}" ]; then
      status='error'
    fi

    if [ -z "${status}" ]; then
      continue # builder rows have no status, node rows do
    fi

    # The first node sets the status, a node that is not running overrides it
    if [ -z "${statuses[${builder}]:-}" ] || [ "${status}" != 'running' ]; then
      statuses["${builder}"]="${status}"
    fi
  done < <(docker buildx ls --format "${template}" 2>/dev/null)

  for builder in "${!statuses[@]}"; do
    echo "${builder} ${statuses[${builder}]}"
  done | sort
}
