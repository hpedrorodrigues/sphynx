#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

readonly script_dir="$(dirname "${BASH_SOURCE[0]}")"

source "${script_dir}/common.sh"

function main() {
  local -r user_os="${1:-}"

  check_operating_system "${user_os}"

  cd "${script_dir}/../${user_os}" && vagrant up
}

main "${@}"
