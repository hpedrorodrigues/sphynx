#!/usr/bin/env bash

function sx::nerdctl::objects() {
  sx::nerdctl::check_requirements

  local -r show_ips="${1:-}"

  if ${show_ips}; then
    local -r template='{{.Name}},{{upper .State.Status}},{{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}'
    local -r output="$(
      nerdctl container ls --all --quiet \
        | xargs nerdctl inspect --format "${template}" \
        | sed 's#^/##'
    )"
    echo -e "NAME,STATUS,IPs\n${output}" | column -t -s ','
  else
    sx::log::info 'Running Containers\n'
    nerdctl container ls \
      --filter 'status=running' \
      --filter 'status=pausing'

    sx::log::info '\nStopped Containers\n'
    nerdctl container ls \
      --filter 'status=created' \
      --filter 'status=paused' \
      --filter 'status=stopped' \
      --filter 'status=unknown'

    sx::log::info '\nImages\n'
    nerdctl image ls

    sx::log::info '\nNetworks\n'
    nerdctl network ls

    sx::log::info '\nVolumes\n'
    nerdctl volume ls
  fi
}
