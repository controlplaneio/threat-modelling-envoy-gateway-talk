#!/bin/bash
kubectl describe pod -n shared \
	$(kubectl get pods -n shared -l app.kubernetes.io/name=envoy -o jsonpath={.items[0].metadata.name}) \
    | grep Image
