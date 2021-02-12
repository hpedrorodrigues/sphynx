#!/usr/bin/env bash

function sx::math::min() {
  local -r first="${1:-}"
  local -r second="${2:-}"

  if [ -z "${first:-}" ]; then
    sx::log::fatal 'This function needs a number as first argument'
  fi

  if [ -z "${second:-}" ]; then
    sx::log::fatal 'This function needs a number as second argument'
  fi

  if [ "${first}" -le "${second}" ]; then
    echo "${first}"
  else
    echo "${second}"
  fi
}

function sx::math::max() {
  local -r first="${1:-}"
  local -r second="${2:-}"

  if [ -z "${first:-}" ]; then
    sx::log::fatal 'This function needs a number as first argument'
  fi

  if [ -z "${second:-}" ]; then
    sx::log::fatal 'This function needs a number as second argument'
  fi

  if [ "${first}" -gt "${second}" ]; then
    echo "${first}"
  else
    echo "${second}"
  fi
}
