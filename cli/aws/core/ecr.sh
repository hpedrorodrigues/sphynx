#!/usr/bin/env bash

function sx::aws::ecr::delete_untagged() {
  sx::aws::check_requirements

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
