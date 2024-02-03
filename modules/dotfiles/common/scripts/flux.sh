#!/usr/bin/env bash

## Print suspended kustomizations
##
## e.g. fxss
function fxss() {
  # Source: https://github.com/fluxcd/flux2/discussions/2494#discussion-3913582
  kubectl get kustomizations.kustomize.toolkit.fluxcd.io \
    --all-namespaces \
    --output json \
    | jq -r '.items[] | select(.spec.suspend==true) | [.metadata.name,.spec.suspend] | @tsv'
}

## Suspend kustomization for the current namespace
##
## e.g. fxsn
function fxsn() {
  local -r current_namespace="$(sx kubernetes namespace --current)"

  flux suspend kustomization "${current_namespace}"
}

## Resume kustomization for the current namespace
##
## e.g. fxsr
function fxsr() {
  local -r current_namespace="$(sx kubernetes namespace --current)"

  flux resume kustomization "${current_namespace}"
}
