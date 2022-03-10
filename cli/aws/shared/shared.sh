#!/usr/bin/env bash

function sx::aws::check_requirements() {
  sx::require_supported_os
  sx::require 'aws' 'aws-cli'

  local -r config_file="${HOME}/.aws/config"

  if ! [ -f "${config_file}" ]; then
    sx::log::fatal 'No such config'
  fi

  if ! [ -s "${config_file}" ]; then
    sx::log::fatal 'Empty config file'
  fi
}
