#!/bin/bash

########################
# include the magic
########################
. demo-magic.sh

# hide the evidence
clear

# malicious httproute

pe "make port-forward-tenant-a"
pe 'curl --verbose --header "Host: www.tenant-a.example.com" http://localhost:8888/get'
wait
clear
pe "make port-forward-shared-tenants"
pe 'curl --verbose --header "Host: www.tenant-b.example.com" http://localhost:8889/get'
wait
clear
pe "cat ./malicious-httproute/tenant-c-malicious-httproute.yaml"
wait
clear
pe "kubectl apply -f ./malicious-httproute/tenant-c-malicious-httproute.yaml"
pe 'curl --verbose --header "Host: www.tenant-b.example.com" http://localhost:8889/totally-legit'
