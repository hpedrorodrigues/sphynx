#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

readonly script_directory="$(dirname "${BASH_SOURCE[0]}")"

function run_action() {
  local -r operating_system="${1:-}"
  local -r action="${2:-}"

  (cd "${script_directory}/${operating_system}" && vagrant "${action}")
}

function main() {
  local -r operating_system="${1:-}"
  local -r action="${2:-}"

  if [ -z "${operating_system}" ] || [ -z "${action}" ]; then
    echo -e "!!! This script requires the operating system and action as arguments." >&2
    echo -e "!!! e.g. ./run.sh ubuntu start" >&2
    exit 1
  fi

  if ! [ -d "${script_directory}/${operating_system}" ]; then
    echo -e "!!! Unsupported operating system: ${action}." >&2
    echo -e "!!! Available options are:" >&2
    find "${script_directory}" -type d -exec basename {} \; -mindepth 1 >&2
    exit 1
  fi

  case "${action}" in
    start)
      run_action "${operating_system}" 'up'
      ;;
    stop)
      run_action "${operating_system}" 'halt'
      ;;
    shell)
      run_action "${operating_system}" 'ssh'
      ;;
    destroy)
      run_action "${operating_system}" 'destroy'
      ;;
    *)
      echo -e "!!! Unsupported action: ${action}." >&2
      exit 1
      ;;
  esac
}

main "${@:-}"
