#!/usr/bin/env bash

function sx::k8s::api_versions() {
  sx::k8s::check_requirements
  sx::require 'jq'

  sx::log::info 'API versions:\n'

  sx::k8s::cli api-versions \
    | sort \
    | grep -Ev '^v1$' \
    | while read -r api_version; do
      sx::log::info "> ${api_version}"
      sx::k8s::cli get --raw "/apis/${api_version}" \
        | jq -r '.resources[].kind' \
        | sort -u \
        | xargs -I % echo '|-- %'
      echo
    done

  sx::log::info '> v1'
  sx::k8s::cli get --raw '/api/v1' \
    | jq -r '.resources[].kind' \
    | sort -u \
    | xargs -I % echo '|-- %'
}
