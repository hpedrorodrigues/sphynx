#!/usr/bin/env bash

## Print pods along with their container images
##
## e.g. kimg
## e.g. kimg -A
function kimg() {
  if ! hash 'kubectl' 2>/dev/null; then
    echo 'The command-line \"kubectl\" is not available in your path' >&2
    return 1
  fi

  # shellcheck disable=SC2016  # Expressions don't expand in single quotes, use double quotes for that
  local -r template='
  {{range .items}}
    {{$namespace := .metadata.namespace}}
    {{$name := .metadata.name}}
    {{"NAMESPACE"}}{{","}}{{"POD"}}{{","}}{{"IMAGE"}}{{"\\n"}}
    {{range .spec.containers}}
      {{$namespace}}{{","}}{{$name}}{{","}}{{.image}}{{"\\n"}}
    {{end}}
  {{end}}'
  local -r cleared_template="$(
    echo -n "${template}" \
      | tr '\n' ' ' \
      | sed 's/}} *{{/}}{{/g' \
      | sed 's/^ *//g'
  )"

  # shellcheck disable=SC2068  # Double quote array expansions
  kubectl get pods \
    --template="${cleared_template}" \
    ${@} \
    | sort -u \
    | column -t -s ','
}

## Print pods highlighting their status
##
## e.g. kgp
## e.g. kgp -A
function kgp() {
  if ! hash 'kubectl' 2>/dev/null; then
    echo 'The command-line \"kubectl\" is not available in your path' >&2
    return 1
  fi

  # shellcheck disable=SC2068  # Double quote array expansions
  kubectl get pods \
    ${@} \
    | GREP_COLOR='01;32' grep --color=always -E 'Completed|$' \
    | GREP_COLOR='01;32' grep --color=always -E 'Running|$' \
    | GREP_COLOR='01;33' grep --color=always -E 'NotReady|$' \
    | GREP_COLOR='01;33' grep --color=always -E 'ContainerCreating|$' \
    | GREP_COLOR='01;33' grep --color=always -E 'PodInitializing|$' \
    | GREP_COLOR='01;33' grep --color=always -E 'Init:[0-9]/[0-9]|$' \
    | GREP_COLOR='01;33' grep --color=always -E 'Pending|$' \
    | GREP_COLOR='01;33' grep --color=always -E 'Terminating|$' \
    | GREP_COLOR='01;31' grep --color=always -E 'OOMKilled|$' \
    | GREP_COLOR='01;31' grep --color=always -E 'CreateContainerConfigError|$' \
    | GREP_COLOR='01;31' grep --color=always -E 'RunContainerError|$' \
    | GREP_COLOR='01;31' grep --color=always -E 'ErrImagePull|$' \
    | GREP_COLOR='01;31' grep --color=always -E 'Init:Error|$' \
    | GREP_COLOR='01;31' grep --color=always -E 'Error|$' \
    | GREP_COLOR='01;31' grep --color=always -E 'Init:CrashLoopBackOff|$' \
    | GREP_COLOR='01;31' grep --color=always -E 'CrashLoopBackOff|$' \
    | GREP_COLOR='01;31' grep --color=always -E 'ImagePullBackOff|$' \
    | GREP_COLOR='01;31' grep --color=always -E 'Evicted|$'
}

## Print nodes highlighting their status
##
## e.g. kgn
function kgn() {
  if ! hash 'kubectl' 2>/dev/null; then
    echo 'The command-line \"kubectl\" is not available in your path' >&2
    return 1
  fi

  # shellcheck disable=SC2068  # Double quote array expansions
  kubectl get nodes \
    ${@} \
    | GREP_COLOR='01;31' grep --color=always -E 'SchedulingDisabled|$' \
    | GREP_COLOR='01;33' grep --color=always -E 'NotReady|$' \
    | GREP_COLOR='01;32' grep --color=always -E ' Ready|$'
}

## Print pods that are not running
##
## e.g. knr
function knr() {
  if ! hash 'kubectl' 2>/dev/null; then
    echo 'The command-line \"kubectl\" is not available in your path' >&2
    return 1
  fi

  # shellcheck disable=SC2068  # Double quote array expansions
  kubectl get pods \
    ${@} \
    --field-selector 'status.phase!=Running' \
    | grep -v 'Complete'
}

## Print the number of pods running on each node
##
## e.g. knp
function knp() {
  if ! hash 'kubectl' 2>/dev/null; then
    echo 'The command-line \"kubectl\" is not available in your path' >&2
    return 1
  fi

  if ! hash 'jq' 2>/dev/null; then
    echo 'The command-line \"jq\" is not available in your path' >&2
    return 1
  fi

  kubectl get pods \
    --output 'json' \
    --all-namespaces \
    | jq '.items
    | group_by(.spec.nodeName)
    | map({"nodeName": .[0].spec.nodeName, "count": length})
    | sort_by(.count)'
}

## [Kubernetes Secrets View] Print secret's data decoded
##
## e.g. ksv
## e.g. ksv -A
function ksv() {
  if ! hash 'kubectl' 2>/dev/null; then
    echo 'The command-line \"kubectl\" is not available in your path' >&2
    return 1
  fi

  # shellcheck disable=SC2016  # Expressions don't expand in single quotes, use double quotes for that
  local -r template='
  {{"NAMESPACE"}}{{","}}{{"SECRET"}}{{","}}{{"KEY"}}{{","}}{{"VALUE"}}{{"\\n"}}
  {{range .items}}
    {{if ne .type "kubernetes.io/service-account-token"}}
      {{$namespace := .metadata.namespace}}
      {{$name := .metadata.name}}
      {{ range $k, $v := .data }}
        {{$namespace}}{{","}}{{$name}}{{","}}{{$k}}{{","}}{{ $v | base64decode}}{{"\\n"}}
      {{end}}
    {{end}}
  {{end}}'
  local -r cleared_template="$(
    echo -n "${template}" \
      | tr '\n' ' ' \
      | sed 's/}} *{{/}}{{/g' \
      | sed 's/^ *//g'
  )"

  # shellcheck disable=SC2068  # Double quote array expansions
  kubectl get secrets \
    --template="${cleared_template}" \
    ${@} \
    | while read -r line; do
      if [[ "${line}" == *','* ]]; then
        echo "${line}"
      else
        echo "-,-,-,${line}"
      fi
    done \
    | column -t -s ','
}

## Print pods along with their IPs
##
## e.g. kpi
## e.g. kpi -A
function kpi() {
  if ! hash 'kubectl' 2>/dev/null; then
    echo 'The command-line \"kubectl\" is not available in your path' >&2
    return 1
  fi

  # shellcheck disable=SC2068  # Double quote array expansions
  kubectl get pods \
    ${@} \
    --output 'custom-columns=POD:.metadata.name,IP:.status.podIPs[*].ip'
}

## Run a pod in the current namespace to help troubleshoot network issues
##
## e.g. kdeb
function kdeb() {
  if ! hash 'kubectl' 2>/dev/null; then
    echo 'The command-line \"kubectl\" is not available in your path' >&2
    return 1
  fi

  local -r pod_name='debug'
  local -r pod_hash="$(uuidgen | cut -d '-' -f 1 | tr '[:upper:]' '[:lower:]')"

  kubectl run "${pod_name}-${pod_hash}" \
    --rm \
    --stdin \
    --tty \
    --image-pull-policy 'Always' \
    --restart 'Never' \
    --labels "app=${pod_name}" \
    --env 'SOURCE=sphynx' \
    --grace-period '1' \
    --image 'hpedrorodrigues/alien:debug'
}

## Diff configurations specified by file name or stdin between the current
## online configuration, and the configuration as it would be if applied.
##
## e.g. kdiff -f pod.yaml
## e.g. cat service.yaml | kdiff -f -
function kdiff() {
  if ! hash 'kubectl' 2>/dev/null; then
    echo 'The command-line \"kubectl\" is not available in your path' >&2
    return 1
  fi

  if ! hash 'delta' 2>/dev/null; then
    echo 'The command-line \"delta\" is not available in your path' >&2
    return 1
  fi

  # shellcheck disable=SC2068  # Double quote array expansions
  kubectl diff ${@} | delta --side-by-side
}

## Prints the instance leader for the selected component.
##
## e.g. kleader
function kleader() {
  if ! hash 'kubectl' 2>/dev/null; then
    echo 'The command-line \"kubectl\" is not available in your path' >&2
    return 1
  fi

  if ! hash 'jq' 2>/dev/null; then
    echo 'The command-line \"jq\" is not available in your path' >&2
    return 1
  fi

  kubectl get endpoints --namespace 'kube-system' --output 'name' \
    | fzf \
    | xargs -I % kubectl get % --namespace 'kube-system' --output 'json' \
    | jq -r '.metadata.annotations."control-plane.alpha.kubernetes.io/leader"' \
    | jq -r '.holderIdentity' \
    | awk -F '_' '{ print $1 }'
}
