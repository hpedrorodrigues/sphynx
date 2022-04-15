#!/usr/bin/env bash

export CLUSTER_NAME='sphynx'

kind delete cluster --name "${CLUSTER_NAME}"
