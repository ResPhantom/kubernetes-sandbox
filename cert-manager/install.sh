#!/bin/bash
helm upgrade --install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace -f values.yaml

# To fully delete
# kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.11.2/cert-manager.crds.yaml