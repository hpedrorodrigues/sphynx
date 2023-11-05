#!/usr/bin/env bash

function sx::error::illegal_arguments() {
  local -r last_argument="${*:${#@}}"
  local -r suffix="$([ -n "${last_argument}" ] && echo ": ${last_argument}")"

  sx::log::fatal "You typed wrong arguments to this command${suffix}"
}
