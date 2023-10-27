#!/bin/bash
kubectl exec -it -n tenant-e \
	$(kubectl get pods -n tenant-e -l app.kubernetes.io/name=envoy -o jsonpath={.items[0].metadata.name}) \
	-- /tcpdump.sh