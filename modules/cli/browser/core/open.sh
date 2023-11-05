#!/usr/bin/env bash

function sx::browser::open() {
  sx::require_supported_os

  sx::os::browser::open "${*}"
}
