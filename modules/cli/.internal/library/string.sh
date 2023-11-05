#!/usr/bin/env bash

function sx::string::lowercase() {
  echo "${1:-$([ -p /dev/stdin ] && cat /dev/stdin)}" | tr '[:upper:]' '[:lower:]'
}

function sx::string::uppercase() {
  echo "${1:-$([ -p /dev/stdin ] && cat /dev/stdin)}" | tr '[:lower:]' '[:upper:]'
}

function sx::string::kebabcase() {
  echo "${1:-$([ -p /dev/stdin ] && cat /dev/stdin)}" | tr '_' '-'
}
