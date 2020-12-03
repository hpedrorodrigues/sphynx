#!/usr/bin/env bash

function sx::github::check_requirements() {
  sx::require 'jq'
  sx::require_env 'GITHUB_TOKEN'
}
