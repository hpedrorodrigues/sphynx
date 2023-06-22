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

function sx::docker::remove_all() {
  sx::docker::check_requirements

  sx::docker::remove_all_containers

  docker system prune --force --all --volumes
}

function sx::docker::clean_up_dirt() {
  sx::docker::check_requirements

  sx::docker::remove_containers
  sx::docker::remove_images
  sx::docker::remove_volumes
  sx::docker::remove_networks
}
