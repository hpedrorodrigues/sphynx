#!/usr/bin/env bash

## Connect to an EC2 instance using AWS Systems Manager Agent
##
## e.g. aws-ssm <instance-id> <region>
function aws-ssm() {
  if ! hash 'aws' 2>/dev/null; then
    echo 'The command-line \"aws\" is not available in your path' >&2
    return 1
  fi

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

  if ! hash 'aws' 2>/dev/null; then
    echo 'The command-line \"aws\" is not available in your path' >&2
    return 1
  fi

  aws ssm start-session \
    --target "${instance_id}" \
    --region "${region}"
}
