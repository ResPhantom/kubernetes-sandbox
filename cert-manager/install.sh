#!/bin/bash

# git repo: 
# helm artifact: 

$(dirname $(readlink -f $0))/../install-lib.sh

NAMESPACE=cert-manager

# install vault
helm upgrade --install vault hashicorp/vault --namespace $NAMESPACE --create-namespace
             --set injector.enabled=false

VAULT_EXEC=kubectl exec vault-0 --namespace $NAMESPACE

# vault init
$VAULT_EXEC -- vault operator init -key-shares=1 \
                    -key-threshold=1 \
                    -format=json > init-keys.json

# # vault unseal
# VAULT_UNSEAL_KEY=$(cat init-keys.json | jq -r ".unseal_keys_b64[]")
# $VAULT_EXEC -- vault operator unseal $VAULT_UNSEAL_KEY

# # vault login
# VAULT_ROOT_TOKEN=$(cat init-keys.json | jq -r ".root_token")
# $VAULT_EXEC -- vault login $VAULT_ROOT_TOKEN


# # Configure PKI Secrets Engine
# vault secrets enable pki
# vault secrets tune -max-lease-ttl=8760h pki

# vault write pki/root/generate/internal \
#     common_name=example.com \
#     ttl=8760h

# vault write pki/config/urls \
#     issuing_certificates="http://vault.default:8200/v1/pki/ca" \
#     crl_distribution_points="http://vault.default:8200/v1/pki/crl"


# vault write pki/roles/example-dot-com \
#     allowed_domains=example.com \
#     allow_subdomains=true \
#     max_ttl=72h

# vault policy write pki - <<EOF
# path "pki*"                        { capabilities = ["read", "list"] }
# path "pki/sign/example-dot-com"    { capabilities = ["create", "update"] }
# path "pki/issue/example-dot-com"   { capabilities = ["create"] }
# EOF





# install certmanager
#helm upgrade --install cert-manager jetstack/cert-manager --namespace $NAMESPACE --create-namespace -f values.yaml





# To fully delete
# kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.11.2/cert-manager.crds.yaml


# Look into using Vault as a kubernetes cert manager
# https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-cert-manager
# https://cert-manager.io/docs/configuration/vault/