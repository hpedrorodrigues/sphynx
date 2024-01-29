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
