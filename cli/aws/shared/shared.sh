#!/usr/bin/env bash

function sx::aws::check_requirements() {
  sx::require_supported_os
  sx::require 'aws' 'aws-cli'
  sx::require_network
}
