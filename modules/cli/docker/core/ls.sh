#!/usr/bin/env bash

function sx::docker::objects() {
  sx::docker::check_requirements

  local -r show_ips="${1:-}"

  if ${show_ips}; then
    local -r template='{{.Name}},{{upper .State.Status}},{{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}'
    local -r output="$(
      docker container ls --all --quiet \
        | xargs docker inspect --format "${template}" \
        | sed 's#^/##'
    )"
    echo -e "NAME,STATUS,IPs\n${output}" | column -t -s ','
  else
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
  fi
}
