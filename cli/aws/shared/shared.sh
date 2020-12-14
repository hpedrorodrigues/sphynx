#!/usr/bin/env bash

function sx::aws::check_requirements() {
  sx::require_supported_os
  sx::require 'aws'
  sx::require_network
}
