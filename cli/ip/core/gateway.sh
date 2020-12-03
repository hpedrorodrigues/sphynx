#!/usr/bin/env bash

function sx::ip::gateway() {
  if sx::os::is_osx; then
    netstat -rn | grep default | head -n 1 | awk '{ print $2 }'
  else
    ip route | grep default | awk '{ print $3 }'
  fi
}
