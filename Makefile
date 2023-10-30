NAME ?= egw
KIND_VERSION ?= v0.20.0
HELM_VERSION ?= 3.13.1

CLUSTER_NAME := $(NAME)

OS := $(shell uname -s | tr '[:upper:]' '[:lower:]')
ARCH := $(shell uname -m | sed 's/x86_64/amd64/')

.EXPORT_ALL_VARIABLES:

##@ Kind

.PHONY: cluster-up
cluster-up: kind ## Create the kind cluster
	$(KIND) create cluster --name $(CLUSTER_NAME) --image kindest/node:v1.27.3

.PHONY: cluster-down
cluster-down: kind ## Delete the kind cluster
	-$(KIND) delete cluster --name $(CLUSTER_NAME)

##@ Envoy Gateway

.PHONY: shared-controller-install ## Install the shared Envoy Gateway
shared-controller-install:
	-$(HELM) install --set config.envoyGateway.gateway.controllerName=gateway.envoyproxy.io/shared-gatewayclass-controller \
	eg-shared oci://docker.io/envoyproxy/gateway-helm --version v0.5.0 \
	-n shared --create-namespace

.PHONY: tenant-a-controller-install ## Install the Tenant A Envoy Gateway
tenant-a-controller-install:
	-$(HELM) install --set config.envoyGateway.gateway.controllerName=gateway.envoyproxy.io/tenant-a-gatewayclass-controller \
	eg-tenant-a oci://docker.io/envoyproxy/gateway-helm --version v0.5.0 \
	-n tenant-a --create-namespace

## Demo environment base infra setup

.PHONY: gwc-tenant-a ## Create the Tenant A GatewayClass
gwc-tenant-a:
	kubectl apply -f ./base-infra/gwc-tenant-a.yaml

.PHONY: gwc-shared ## Create the Shared GatewayClass
gwc-shared:
	kubectl apply -f ./base-infra/gwc-shared.yaml

.PHONY: shared-gw-create ## Create the Shared Gateway
shared-gw-create:
	kubectl apply -f ./base-infra/shared-gw.yaml

.PHONY: run-backend-services ## Run the backend services for Tenants A, B, C and D
run-backend-services:
	kubectl apply -f ./base-infra/tenant-a.yaml
	kubectl apply -f ./base-infra/tenant-b.yaml
	kubectl apply -f ./base-infra/tenant-c.yaml
	kubectl apply -f ./base-infra/tenant-d.yaml

.PHONY: demo-base-infra ## Set up the base infra, ready to run demo-magic scripts
demo-base-infra: cluster-up tenant-a-controller-install shared-controller-install gwc-tenant-a gwc-shared shared-gw-create run-backend-services

## Malicious HTTPRoute scenario

.PHONY: malicious-httproute ## Create malicious HTTPRoute in the tenant-c ns, receiving traffic intended for tenant-b
malicious-httproute:
	kubectl apply -f ./malicious-httproute/tenant-c-malicious-httproute.yaml

## Exploring ReferenceGrants

.PHONY: cross-ns-route-create ## Create an HTTPRoute in the tenant-a ns which references a Tenant D backend
cross-ns-route-create:	
	kubectl apply -f ./exploring-reference-grants/cross-ns-route.yaml
	
.PHONY: ref-grant-create ## Create a ReferenceGrant which permits such an HTTPRoute
ref-grant-create:	
	kubectl apply -f ./exploring-reference-grants/ref-grant.yaml

## Port forward connections

.PHONY: port-forward-tenant-a ## Forward connections to localhost:8888 to the Tenant A Gateway
port-forward-tenant-a:
	$(eval ENVOY_SERVICE_A := $(shell kubectl get svc -n tenant-a --selector=gateway.envoyproxy.io/owning-gateway-namespace=tenant-a,gateway.envoyproxy.io/owning-gateway-name=eg -o jsonpath='{.items[0].metadata.name}'))
	kubectl -n tenant-a port-forward service/${ENVOY_SERVICE_A} 8888:8080 &

.PHONY: port-forward-shared-tenants ## Forward connections to localhost:8889 to the Shared Gateway
port-forward-shared-tenants:
	$(eval ENVOY_SERVICE_SHARED := $(shell kubectl get svc -n shared --selector=gateway.envoyproxy.io/owning-gateway-namespace=shared,gateway.envoyproxy.io/owning-gateway-name=eg -o jsonpath='{.items[0].metadata.name}'))
	kubectl -n shared port-forward service/${ENVOY_SERVICE_SHARED} 8889:8080 &

.PHONY: port-forward-tenant-e ## Forward connections to localhost:8888 to the Tenant E Gateway
port-forward-tenant-e:
	$(eval ENVOY_SERVICE_E := $(shell kubectl get svc -n tenant-e --selector=gateway.envoyproxy.io/owning-gateway-namespace=tenant-e,gateway.envoyproxy.io/owning-gateway-name=eg -o jsonpath='{.items[0].metadata.name}'))
	kubectl -n tenant-e port-forward service/${ENVOY_SERVICE_E} 8890:8080 &

.PHONY: stop-port-forwarding
stop-port-forwarding:
	-lsof -ti:8888 | xargs kill -9
	-lsof -ti:8889 | xargs kill -9
	-lsof -ti:8890 | xargs kill -9

## Curl backend services

.PHONY: curl-tenant-a
curl-tenant-a:
	curl --verbose --header "Host: www.tenant-a.example.com" http://localhost:8888/get

.PHONY: curl-tenant-b
curl-tenant-b:
	curl --verbose --header "Host: www.tenant-b.example.com" http://localhost:8889/get

.PHONY: curl-tenant-c
curl-tenant-c:
	curl --verbose --header "Host: www.tenant-c.example.com" http://localhost:8889/get

.PHONY: curl-tenant-b-malicious
curl-tenant-b-malicious:
	curl --verbose --header "Host: www.tenant-b.example.com" http://localhost:8889/totally-legit

.PHONY: curl-tenant-d
curl-tenant-d:
	curl --verbose --header "Host: www.tenant-d.example.com" http://localhost:8888/get

.PHONY: curl-tenant-e
curl-tenant-e:
	curl --verbose --header "Host: www.tenant-e.example.com" http://localhost:8890/get

## Compromised proxy scenario

.PHONY: build-malicious-envoy ## Build toy 'malicious proxy' with a simple tcpdump script copied in
build-malicious-envoy:
	docker build -t tcpdump-envoy:v0.1 compromised-proxy
	kind load docker-image tcpdump-envoy:v0.1 -n $(CLUSTER_NAME)

.PHONY: tenant-e-infra-install ## Create new GatewayClass referring to malicious EnvoyProxy, a Gateway which uses this GatewayClass, and HTTPRoute to Tenant E backend
tenant-e-infra-install:
	-$(HELM) install --set config.envoyGateway.gateway.controllerName=gateway.envoyproxy.io/tenant-e-gatewayclass-controller \
	eg-tenant-e oci://docker.io/envoyproxy/gateway-helm --version v0.5.0 \
	-n tenant-e --create-namespace
	kubectl apply -f ./compromised-proxy/tenant-e.yaml

.PHONY: exec-into-proxy-e ## Run tcpdump script from within the 'malicious' Tenant E Envoy Proxy
exec-into-proxy-e:
	scripts/exec-into-proxy-e.sh

## Compromised controller scenario

.PHONY: create-malicious-proxy ## Create 'malicious' EnvoyProxy resource in tenant-a namespace
create-malicious-proxy:
	kubectl apply -f ./compromised-controller/malicious-proxy.yaml

.PHONY: patch-gatewayclass ## Attempt to patch the shared GatewayClass to refer to this EnvoyProxy
patch-gatewayclass:
	./scripts/perform-action-as-gateway.sh \ 
	kubectl apply -f ./compromised-controller/malicious-gatewayclass.yaml

.PHONY: restart-shared-pods
restart-shared-pods:
	./scripts/restart-shared-pods.sh

.PHONY: grep-shared-envoy-image ## Observe that we were not successful in changing the shared proxy image
grep-shared-envoy-image:
	./scripts/grep-envoy-image.sh

##@ Tools

.PHONY: kind
KIND = $(shell pwd)/bin/kind
kind: ## Download kind if required
ifeq (,$(wildcard $(KIND)))
ifeq (,$(shell which kind 2> /dev/null))
	@{ \
		mkdir -p $(dir $(KIND)); \
		curl -sSLo $(KIND) https://kind.sigs.k8s.io/dl/$(KIND_VERSION)/kind-$(OS)-$(ARCH); \
		chmod + $(KIND); \
	}
else
KIND = $(shell which kind)
endif
endif

.PHONY: helm
HELM = $(shell pwd)/bin/helm
helm: ## Download helm if required
ifeq (,$(wildcard $(HELM)))
ifeq (,$(shell which helm 2> /dev/null))
	@{ \
		mkdir -p $(dir $(HELM)); \
		curl -sSLo $(HELM).tar.gz https://get.helm.sh/helm-v$(HELM_VERSION)-$(OS)-$(ARCH).tar.gz; \
		tar -xzf $(HELM).tar.gz --one-top-level=$(dir $(HELM)) --strip-components=1; \
		chmod + $(HELM); \
	}
else
HELM = $(shell which helm)
endif
endif