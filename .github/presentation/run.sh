#!/usr/bin/env bash

readonly script_dir="$(dirname ${BASH_SOURCE[0]})"

# Cluster
kind create cluster \
  --name 'sphynx' \
  --config "${script_dir}/multi-node-cluster.yaml"

# Resources
readonly namespace_name='sphynx'

kubectl create namespace "${namespace_name}"
kubectl config set-context --current --namespace="${namespace_name}"

kubectl create deployment echoserver \
  --image=k8s.gcr.io/echoserver:1.4 \
  --replicas=5
