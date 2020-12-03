#!/usr/bin/env bash

export SX_OPENSHIFT_DEFAULT_RESOURCES='pods,deployments,deploymentconfigs,services,ingresses,routes,replicasets,replicationcontrollers,configmaps,secrets,serviceaccounts,cronjobs,daemonsets,statefulsets,hpa,nodes'
export SX_OPENSHIFT_RESOURCES="${SX_OPENSHIFT_RESOURCES:-${SX_OPENSHIFT_DEFAULT_RESOURCES}}"

function sx::openshift::check_requirements() {
  sx::require 'oc'
}

function sx::openshift::current_project() {
  oc project --short
}

function sx::openshift::all_projects() {
  local -r current_project="$(sx::openshift::current_project)"

  oc projects --short \
    | sort -n \
    | xargs -I % sh -c "[ '${current_project}' = '%' ] && echo '% *' || echo '%'"
}
