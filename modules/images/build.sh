#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

##? Build
##?
##? Usage:
##?   build [--push] | [--help]
##?
##? Commands:
##?   --push  Build and push docker image(s) to Dockerhub [default: all images]
##?   --help  Print this help message

export IMAGES_PATH="${IMAGES_PATH:-${SPHYNX_DIR:-.}/modules/images}"
export DOCKER_REPOSITORY="${DOCKER_REPOSITORY:-hpedrorodrigues/alien}"

function print_help() {
  grep '[#]#?' "${BASH_SOURCE[0]}" | cut -c 5-
}

function run_over_all() {
  local -r action="${1:-}"

  if [ -z "${action}" ]; then
    echo 'This function needs an argument (the action to run)' >&2
    exit 1
  fi

  while IFS= read -r -d '' directory; do
    echo -e "\n==|> Running \"${action}\" over \"${directory}\"\n"
    "${action}" "${directory}"
  done < <(find "${IMAGES_PATH}" ! -path "${IMAGES_PATH}" -type d -print0 | sort -z)
}

function build_image() {
  local -r recipe_path="${1:-}"

  if [ -z "${recipe_path}" ]; then
    echo 'This function needs an argument (the directory with the Dockerfile)' >&2
    exit 1
  fi

  if ! [ -d "${recipe_path}" ]; then
    echo 'The given directory does not exist' >&2
    exit 1
  fi

  local -r tag="$(basename "${recipe_path}")"
  local -r platforms="$(tr '\n' ',' <"${recipe_path}/.platforms" | sed 's/,$/\n/')"

  docker buildx build "${recipe_path}" \
    --platform "${platforms}" \
    --tag "${DOCKER_REPOSITORY}:${tag}"
}

function build_and_push_image() {
  local -r recipe_path="${1:-}"

  if [ -z "${recipe_path}" ]; then
    echo 'This function needs an argument (the directory with the Dockerfile)' >&2
    exit 1
  fi

  if ! [ -d "${recipe_path}" ]; then
    echo 'The given directory does not exist' >&2
    exit 1
  fi

  local -r tag="$(basename "${recipe_path}")"
  local -r platforms="$(tr '\n' ',' <"${recipe_path}/.platforms" | sed 's/,$/\n/')"

  docker buildx build "${recipe_path}" \
    --platform "${platforms}" \
    --push \
    --tag "${DOCKER_REPOSITORY}:${tag}"
}

function main() {
  if [ -z "${1:-}" ]; then
    run_over_all build_image
  elif [ "${1:-}" == '--push' ]; then
    run_over_all build_and_push_image
  else
    print_help
  fi
}

main "${@}"
