#!/usr/bin/env bash

export SX_GCLOUDCTL="${SX_GCLOUDCTL:-gcloud}"

export SX_GCLOUD_CONFIG_FILE="${SX_GCLOUD_CONFIG_FILE:-${HOME}/.config/gcloud/sphynx_configurations}"
export SX_GCLOUD_PROJECT_FILE="${SX_GCLOUD_PROJECT_FILE:-${HOME}/.config/gcloud/sphynx_projects}"

function sx::gcloud::check_requirements() {
  sx::require_supported_os
  sx::require 'gcloud'
}

function sx::gcloud::cli() {
  # shellcheck disable=SC2086  # quote this to prevent word splitting
  ${SX_GCLOUDCTL} "${@}"
}

function sx::gcloud::named_configuration::current() {
  sx::gcloud::cli config configurations list \
    --format='value(name)' \
    --filter='is_active=true'
}

function sx::gcloud::named_configuration::list() {
  sx::gcloud::cli config configurations list --format='value(name)'
}

function sx::gcloud::named_configuration::change() {
  local -r new_named_configuration="${1:-}"

  sx::log::info "Activating configuration \"${new_named_configuration}\"\n"

  local -r current_named_configuration="$(sx::gcloud::named_configuration::current)"
  [ "${current_named_configuration}" != "${new_named_configuration}" ] \
    && [ -n "${current_named_configuration}" ] \
    && sx::file::write_replacing "${SX_GCLOUD_CONFIG_FILE}" "${current_named_configuration}"

  sx::gcloud::cli config configurations activate "${new_named_configuration}"
}

function sx::gcloud::project::current() {
  sx::gcloud::cli config list \
    --format 'value(core.project)'
}

function sx::gcloud::project::list() {
  sx::gcloud::cli projects list \
    --format='value[separator=","](projectNumber, projectId, name, lifecycleState)' \
    | column -t -s ','
}

function sx::gcloud::project::change() {
  local -r project_id="${1:-}"

  sx::log::info "Switching to project \"${project_id}\"\n"

  local -r current_project="$(sx::gcloud::project::current)"
  [ "${current_project}" != "${project_id}" ] \
    && [ -n "${current_project}" ] \
    && sx::file::write_replacing "${SX_GCLOUD_PROJECT_FILE}" "${current_project}"

  sx::gcloud::cli config set project "${project_id}"
}
