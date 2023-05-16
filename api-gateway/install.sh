#!/bin/bash
kubectl apply -f https://raw.githubusercontent.com/hashicorp/consul-api-gateway/main/config/crd/bases/api-gateway.consul.hashicorp.com_gatewayclassconfigs.yaml
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v0.6.2/standard-install.yaml
helm upgrade --install consul hashicorp/consul --set global.name=consul --create-namespace -n consul -f values.yaml
kubectl apply -f ing.yaml