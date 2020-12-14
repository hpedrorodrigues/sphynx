#!/usr/bin/env bash

function sx::macos::check_requirements() {
  sx::require_osx
}

function sx::macos::restart_ui() {
  sx::macos::check_requirements

  killall SystemUIServer
}
