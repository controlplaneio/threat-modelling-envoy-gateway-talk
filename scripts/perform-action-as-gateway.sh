#!/bin/bash

if [[ $# -eq 0 ]] ; then
    echo 'Enter a command to be run with the permissions of Envoy Gateway'
    exit 0
fi

kubectl config set users.test.token '${TEST_TOKEN}' --set-raw-bytes=true
kubectl config set contexts.kind-test.cluster kind-egw
kubectl config set contexts.kind-test.user test

export TEST_TOKEN=$(kubectl create token envoy-gateway -n tenant-a)

if [ -f kube-config.yaml ]; then rm kube-config.yaml; fi
envsubst < ~/.kube/config > kube-config.yaml

$(echo "${@: 1}") --context kind-test --kubeconfig ./kube-config.yaml

kubectl config delete-context kind-test
kubectl config delete-user test

rm kube-config.yaml