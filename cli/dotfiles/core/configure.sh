#!/usr/bin/env bash

export DOTBOT_CONFIG_FILE='dotbot.conf.yaml'

function sx::dotfiles::check_requirements() {
  sx::require_supported_os
  sx::require 'dotbot'
}

function sx::dotfiles::configure() {
  sx::dotfiles::check_requirements

  dotbot -c "${SPHYNX_DIR}/dotfiles/${DOTBOT_CONFIG_FILE}"
}
