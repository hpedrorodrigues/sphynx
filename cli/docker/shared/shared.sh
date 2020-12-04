#!/usr/bin/env bash

function sx::docker::check_requirements() {
  sx::require 'docker'
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
