#!/usr/bin/env bash

function sx::github::check_requirements() {
  sx::require_supported_os
  sx::require 'jq'
  sx::require_env 'GITHUB_TOKEN'
  sx::require_network
}
