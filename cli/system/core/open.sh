#!/usr/bin/env bash

function sx::system::open() {
  sx::os::ensure_supported_os

  sx::os::open "${*}"
}
