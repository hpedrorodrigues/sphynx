#!/usr/bin/env bash

function sx::docker::objects() {
  sx::docker::check_requirements

  sx::log::info 'Running Containers\n'
  docker container ls \
    --filter 'status=running' \
    --filter 'status=restarting' \
    --filter 'status=removing'

  sx::log::info '\nStopped Containers\n'
  docker container ls \
    --filter 'status=created' \
    --filter 'status=paused' \
    --filter 'status=exited' \
    --filter 'status=dead'

  sx::log::info '\nImages\n'
  docker images

  sx::log::info '\nNetworks\n'
  docker network ls

  sx::log::info '\nVolumes\n'
  docker volume ls
}
