#!/usr/bin/env bash

function sx::system::open() {
  sx::system::check_requirements

  sx::os::open "${*}"
}
