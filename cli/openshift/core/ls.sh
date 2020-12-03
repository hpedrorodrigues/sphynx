#!/usr/bin/env bash

function sx::openshift::list::resources() {
  sx::openshift::check_requirements

  oc get "${SX_OPENSHIFT_RESOURCES}"
}
