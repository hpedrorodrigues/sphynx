#!/usr/bin/env bash

# References:
# - https://wiki.termux.com/wiki/Termux-services
# - http://smarden.org/runit

function sx::termux::check_requirements() {
  sx::android::check_requirements

  if ! sx::android::is_package_available 'com.termux'; then
    sx::log::fatal 'Termux is not installed!'
  fi
}
