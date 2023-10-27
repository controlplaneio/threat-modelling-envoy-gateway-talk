#!/bin/bash
kubectl delete pod -n shared \
	$(kubectl get pods -n shared -l app.kubernetes.io/name=gateway-helm -o jsonpath={.items[0].metadata.name})

kubectl delete pod -n shared \
	$(kubectl get pods -n shared -l app.kubernetes.io/name=envoy -o jsonpath={.items[0].metadata.name})