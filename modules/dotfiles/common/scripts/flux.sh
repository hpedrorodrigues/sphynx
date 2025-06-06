#!/usr/bin/env bash

## Force Helm Controller to perform a Helm install or upgrade without making
## changes to the spec.
##
## e.g. fr litellm
##
## Reference: https://fluxcd.io/flux/components/helm/helmreleases/#forcing-a-release
function fr() {
  local -r func_name="${FUNCNAME[0]:-${funcstack[1]}}"
  local -r release_name="${1:-}"
  if [ -z "${release_name}" ]; then
    echo '!!! You should pass a release name to this function' >&2
    echo "!!! e.g. ${func_name} litellm" >&2
    return 1
  fi

  if ! hash 'kubectl' 2>/dev/null; then
    echo 'The command-line \"kubectl\" is not available in your path' >&2
    return 1
  fi

  local -r token="$(date +%s)"
  kubectl annotate "helmrelease/${release_name}" \
    --overwrite \
    --field-manager='flux-client-side-apply' \
    "reconcile.fluxcd.io/requestedAt=${token}" \
    "reconcile.fluxcd.io/forceAt=${token}"
}
