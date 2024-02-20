#!/usr/bin/env bash

export FLUX_LABEL_FILTER="${FLUX_LABEL_FILTER:-fluxcd.io}"

function sx::k8s::is_managed_by_flux() {
  local -r ns="${1}"
  local -r kind="${2}"
  local -r name="${3}"

  sx::k8s::cli get "${kind}"/"${name}" \
    --namespace "${ns}" \
    --show-labels \
    | grep "${FLUX_LABEL_FILTER}" -q
}
