#!/usr/bin/env bash

## Connect to an EC2 instance using AWS Systems Manager Agent
##
## e.g. aws-ssm <instance-id> <region>
function aws-ssm() {
  local -r func_name="${FUNCNAME[0]:-${funcstack[1]}}"
  local -r instance_id="${1}"
  local -r region="${2:-us-east-1}"

  if [ -z "${instance_id}" ]; then
    echo '!!! This function needs an instance-id as first argument' >&2
    echo "!!! e.g. ${func_name} <instance-id> <region> # default is us-east-1" >&2
    return 1
  fi

  if [ -z "${region}" ]; then
    echo '!!! This function needs a region as second argument' >&2
    echo "!!! e.g. ${func_name} <instance-id> <region> # default is us-east-1" >&2
    return 1
  fi

  aws ssm start-session \
    --target "${instance_id}" \
    --region "${region}"
}

## Search ECS services using the provided query
##
## e.g. aws-ecs-search <my-service> <region>
##
## TODO: Refactor this function to remove chained-loops
function aws-ecs-search() {
  local -r func_name="${FUNCNAME[0]:-${funcstack[1]}}"
  local -r service_query="${1:-}"
  local -r region="${2:-us-east-1}"

  if [ -z "${service_query}" ]; then
    echo '!!! This function needs a service query as first argument' >&2
    echo "!!! e.g. ${func_name} <my-service>" >&2
    return 1
  fi

  if [ -z "${region}" ]; then
    echo '!!! This function needs a region as second argument' >&2
    echo "!!! e.g. ${func_name} <my-service> <region> # default is us-east-1" >&2
    return 1
  fi

  aws ecs list-clusters --region "${region}" \
    | jq --monochrome-output --raw-output '.clusterArns | .[]' \
    | sort -u \
    | while read -r cluster; do
      aws ecs list-services --cluster "${cluster}" --region "${region}" \
        | jq --monochrome-output --raw-output '.serviceArns | .[]' \
        | sort -u \
        | grep "${service_query}" \
        | while read -r service; do
          aws ecs list-tasks --cluster "${cluster}" --service-name "${service}" --region "${region}" \
            | jq --monochrome-output --raw-output '.taskArns | .[]' \
            | while read -r task; do
              aws ecs describe-tasks --cluster "${cluster}" --tasks "${task}" --region "${region}" \
                | jq --monochrome-output --raw-output '.tasks[].containerInstanceArn' \
                | while read -r container_instance; do
                  aws ecs describe-container-instances --cluster "${cluster}" --container-instances "${container_instance}" --region "${region}" \
                    | jq --monochrome-output --raw-output '.containerInstances[].ec2InstanceId' \
                    | while read -r instance_id; do
                      echo "> ${cluster}"
                      echo "|-- (Service)             ${service}"
                      echo "|-- (Task)                ${task}"
                      echo "|-- (Container Instance)  ${container_instance}"
                      echo "|-- (Instance ID)         ${instance_id}"
                      echo
                    done
                done
            done
        done
    done
}