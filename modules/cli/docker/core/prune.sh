#!/usr/bin/env bash

function sx::docker::remove_all_containers() {
  sx::docker::check_requirements

  docker container ls --no-trunc --quiet --all \
    | xargs -I % docker rm --volumes --force %
}

function sx::docker::remove_containers() {
  sx::docker::check_requirements

  docker container prune --force
}

function sx::docker::remove_images() {
  sx::docker::check_requirements

  docker image prune --all --force
}

function sx::docker::remove_volumes() {
  sx::docker::check_requirements

  docker volume prune --all --force
}

function sx::docker::remove_networks() {
  sx::docker::check_requirements

  docker network prune --force
}

function sx::docker::remove_builds() {
  sx::docker::check_requirements
  sx::docker::ensure_buildx_history

  local builder status

  while read -r builder status; do
    if [ "${status}" != 'running' ]; then
      sx::log::info "Skipping builder [${builder}]: driver is ${status}"
      continue
    fi

    sx::log::info "Pruning builder [${builder}]"

    docker buildx prune --force --builder "${builder}"
    docker buildx history rm --all --builder "${builder}"
  done < <(sx::docker::buildx_builders)
}

function sx::docker::remove_all() {
  sx::docker::check_requirements

  # Prune the builders before the containers: removing every container also
  # removes the BuildKit container of a docker-container builder, and buildx
  # cannot prune a builder whose driver is not running.
  if sx::docker::has_buildx_history; then
    sx::docker::remove_builds
  fi

  sx::docker::remove_all_containers
  sx::docker::remove_volumes

  docker system prune --force --all --volumes
}
