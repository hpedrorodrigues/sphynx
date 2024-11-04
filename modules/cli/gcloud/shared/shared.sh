#!/usr/bin/env bash

function sx::gcloud::check_requirements() {
  sx::require_supported_os
  sx::require 'gcloud'
}

function sx::gcloud::named_configuration::current() {
  gcloud config configurations list \
    --format='value(name)' \
    --filter='is_active=true'
}

function sx::gcloud::named_configuration::list() {
  gcloud config configurations list --format='value(name)'
}

function sx::gcloud::named_configuration::change() {
  local -r new_named_configuration="${1:-}"

  gcloud config configurations activate "${new_named_configuration}"
}

function sx::gcloud::project::current() {
  gcloud config list \
    --format 'value(core.project)'
}

function sx::gcloud::project::list() {
  gcloud projects list \
    --format='value[separator=","](projectNumber, projectId, name, lifecycleState)' \
    | column -t -s ','
}

function sx::gcloud::project::change() {
  local -r project_id="${1:-}"

  gcloud config set project "${project_id}"
}
