#!/usr/bin/env bash

function sx::system::open() {
  sx::require_supported_os

  sx::os::open "${*}"
}
