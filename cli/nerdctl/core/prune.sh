#!/usr/bin/env bash

function sx::nerdctl::remove_all_containers() {
  sx::nerdctl::check_requirements

  nerdctl container ls --no-trunc --quiet --all \
    | xargs -I % nerdctl rm --volumes --force %
}

function sx::nerdctl::remove_containers() {
  sx::nerdctl::check_requirements

  nerdctl container prune --force
}

function sx::nerdctl::remove_images() {
  sx::nerdctl::check_requirements

  nerdctl image prune --all --force
}

function sx::nerdctl::remove_volumes() {
  sx::nerdctl::check_requirements

  nerdctl volume prune --force
}

function sx::nerdctl::remove_networks() {
  sx::nerdctl::check_requirements

  nerdctl network prune --force
}

function sx::nerdctl::remove_all() {
  sx::nerdctl::check_requirements

  sx::nerdctl::remove_all_containers

  nerdctl system prune --force --all --volumes
}

function sx::nerdctl::clean_up_dirt() {
  sx::nerdctl::check_requirements

  sx::nerdctl::remove_containers
  sx::nerdctl::remove_images
  sx::nerdctl::remove_volumes
  sx::nerdctl::remove_networks
}
