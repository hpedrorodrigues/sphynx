#!/usr/bin/env bash

function sx::aws::ecr::clear_untagged() {
  sx::aws::check_requirements
  sx::require_network

  aws ecr describe-repositories \
    | jq -r '.repositories[].repositoryName' \
    | while read -r repository_name; do

      sx::log::info "Deleting untagged images from repository \"${repository_name}\"."

      aws ecr list-images \
        --repository-name "${repository_name}" \
        --filter 'tagStatus=UNTAGGED' \
        --query 'imageIds[*]' \
        --output 'text' \
        | while read -r image_id; do

          aws ecr batch-delete-image \
            --repository-name "${repository_name}" \
            --image-ids "imageDigest=${image_id}"
        done
    done

  sx::log::info 'Done!'
}

function sx::aws::ecr::delete_untagged_from_repository() {
  sx::aws::check_requirements
  sx::require_network

  local -r repository_name="${1:-}"
  if [ -z "${repository_name}" ]; then
    sx::log::fatal 'This function needs a repository as first argument'
  fi

  if ! sx::aws::ecr::repository_exists "${repository_name}"; then
    sx::log::fatal "Repository \"${repository_name}\" not found"
  fi

  sx::log::info "Deleting untagged images from repository \"${repository_name}\"."

  aws ecr list-images \
    --repository-name "${repository_name}" \
    --filter 'tagStatus=UNTAGGED' \
    --query 'imageIds[*]' \
    --output 'text' \
    | while read -r image_id; do
      aws ecr batch-delete-image \
        --repository-name "${repository_name}" \
        --image-ids "imageDigest=${image_id}"
    done

  sx::log::info 'Done!'
}

function sx::aws::ecr::repository_exists() {
  local -r repository_name="${1:-}"

  aws ecr describe-repositories \
    | jq --exit-status ".repositories[] | select(.repositoryName == \"${repository_name}\") | .repositoryName" \
      &>/dev/null
}
