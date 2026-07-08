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

  docker buildx prune --force
  docker buildx history rm --all
}

function sx::docker::remove_all() {
  sx::docker::check_requirements

  sx::docker::remove_all_containers
  sx::docker::remove_volumes

  if sx::docker::has_buildx_history; then
    sx::docker::remove_builds
  fi

  docker system prune --force --all --volumes
}
