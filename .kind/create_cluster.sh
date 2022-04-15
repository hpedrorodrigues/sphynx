#!/usr/bin/env bash

export SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
export CLUSTER_NAME='sphynx'
export NAMESPACE_NAME='sphynx'

### Cluster

kind create cluster \
  --name "${CLUSTER_NAME}" \
  --config "${SCRIPT_DIR}/cluster-config.yaml"

### Resources

kubectl create namespace "${NAMESPACE_NAME}"
kubectl config set-context --current --namespace="${NAMESPACE_NAME}"

if [ "$(uname)" = 'Darwin' ] \
  && [ "$(sysctl -n machdep.cpu.brand_string)" = 'Apple M1' ]; then
  export IMAGE_NAME='e2eteam/echoserver:2.2-linux-arm64'
else
  export IMAGE_NAME='k8s.gcr.io/echoserver:2.2'
fi

kubectl create deployment echoserver \
  --namespace "${NAMESPACE_NAME}" \
  --image "${IMAGE_NAME}" \
  --replicas 5
