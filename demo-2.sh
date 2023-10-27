#!/bin/bash

########################
# include the magic
########################
. demo-magic.sh

# hide the evidence
clear

# malicious image

pe "cat ./compromised-proxy/Dockerfile"
wait
clear
pe "docker build -t tcpdump-envoy:v0.1 compromised-proxy"
pe "kind load docker-image tcpdump-envoy:v0.1 -n egw"
clear
pe 'helm install --set config.envoyGateway.gateway.controllerName=gateway.envoyproxy.io/tenant-e-gatewayclass-controller eg-tenant-e oci://docker.io/envoyproxy/gateway-helm --version v0.5.0 -n tenant-e --create-namespace'
pe "head ./compromised-proxy/tenant-e.yaml -n 24"
wait
clear
pe "kubectl apply -f ./compromised-proxy/tenant-e.yaml"
pe 'kubectl exec -it -n tenant-e $(kubectl get pods -n tenant-e -l app.kubernetes.io/name=envoy -o jsonpath={.items[0].metadata.name}) -- /tcpdump.sh'