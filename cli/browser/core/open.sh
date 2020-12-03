#!/usr/bin/env bash

function sx::browser::open() {
  sx::os::ensure_supported_os

  sx::os::browser::open "${*}"
}
