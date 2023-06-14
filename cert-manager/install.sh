#!/bin/bash

# SETUP WAS DONE FOLLOWING THESE GUIDE(S):
# https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-cert-manager
# https://developer.hashicorp.com/vault/tutorials/secrets-management/pki-engine
# https://sestegra.medium.com/build-an-internal-pki-with-vault-f7179306f18c

# REQUIREMENTS:
#   - kubectl
#   - linux (amd64)

# import common functions and variables
. $(dirname $(readlink -f $0))/../install-lib.sh

export VAULT_SKIP_VERIFY=true
export VAULT_ADDR="https://${HOSTNAME}"

VAULT_VERSION=""
NAMESPACE="cert-manager"
HOSTNAME="vault.${DOMAIN}"
LOCAL_HOSTNAME="vault.${NAMESPACE}.svc.cluster.local:8200"

enable_debug=true

# -----------------------------------------------------------------------
# git repo: https://github.com/hashicorp/vault-helm/blob/main/values.yaml
# helm artifact: https://artifacthub.io/packages/helm/hashicorp/vault
# -----------------------------------------------------------------------

# install vault
helm upgrade --install vault hashicorp/vault --namespace ${NAMESPACE} --create-namespace \
             --set server.ingress.enabled=true \
             --set server.ingress.hosts[0].host=${HOSTNAME} \
             --set server.ingress.tls[0].secretName=${HOSTNAME} \
             --set server.ingress.tls[0].hosts[0]=${HOSTNAME} \
             --set injector.enabled=false

# update ingress annotation to generate kubernetes certificate object
kubectl annotate ing vault -n ${NAMESPACE} \
        --overwrite cert-manager.io/cluster-issuer="vault-issuer" \
        cert-manager.io/common-name="${HOSTNAME}"

# -----------------------------------------------------------------------
# Set up vault
# -----------------------------------------------------------------------

# wait for vault to be ready
countdown 10

# delete tmp folder
rm -rf ./tmp

# create tmp folder
mkdir ./tmp && cd ./tmp

# get tools
kubectl cp $NAMESPACE/vault-0:/bin/vault ./vault
curl -SL https://github.com/jqlang/jq/releases/download/jq-1.6/jq-linux32 -o jq
cp ../certstrap .

# set execution permissions
chmod 555 vault jq certstrap

if ${enable_debug};then set -x;fi

# vault init
./vault operator init -key-shares=1 \
                    -key-threshold=1 \
                    -format=json > keys.json

# vault remote
VAULT_EXEC="kubectl exec vault-0 --namespace ${NAMESPACE}"

# vault unseal
VAULT_UNSEAL_KEY=$(cat keys.json | ./jq -r ".unseal_keys_b64[]")
./vault operator unseal ${VAULT_UNSEAL_KEY}

# vault login
VAULT_ROOT_TOKEN=$(cat keys.json | ./jq -r ".root_token")
./vault login ${VAULT_ROOT_TOKEN}
${VAULT_EXEC} -- vault login ${VAULT_ROOT_TOKEN}

# -----------------------------------------------------------------------
# Configure PKI Secrets Engine - Create pki secret
# -----------------------------------------------------------------------

# enable pki - intermediate
./vault secrets enable -path=pki_int pki
./vault secrets tune -max-lease-ttl=43800h pki_int

./vault write pki_int/config/urls \
                  issuing_certificates="http://${HOSTNAME}/v1/pki/ca" \
                  crl_distribution_points="http://${HOSTNAME}/v1/pki/crl"

# enable pki - issuer
./vault secrets enable -path=pki_iss pki
./vault secrets tune -max-lease-ttl=8760h pki_iss

./vault write pki_iss/config/urls \
                  issuing_certificates="http://${HOSTNAME}/v1/pki/ca" \
                  crl_distribution_points="http://${HOSTNAME}/v1/pki/crl"

# -----------------------------------------------------------------------
# Configure PKI Secrets Engine - Create certificates
# -----------------------------------------------------------------------

ORGANIZATION="resphantom"
COMMON_NAME="resphantom"

# ROOT CERT
./certstrap --depot-path root init \
            --organization "${ORGANIZATION}" \
            --common-name "${COMMON_NAME} Root CA v1" \
            --expires "10 years" \
            --curve P-256 \
            --path-length 2 \
            --passphrase "secret"

cp ./root/*.crt pki_root_v1.crt

# INTERMEDIATE CERT
./vault write -format=json \
        pki_int/intermediate/generate/internal \
        organization="${ORGANIZATION}" \
        common_name="${COMMON_NAME} Intermediate CA v1.1" \
        issuer_name="vault-intermediate" \
        key_bits=4096 \
        | ./jq -r '.data.csr' > pki_int_v1.1.csr

./certstrap --depot-path root sign \
            --CA "${COMMON_NAME} Root CA v1" \
            --intermediate \
            --csr pki_int_v1.1.csr \
            --expires "5 years" \
            --path-length 1 \
            --passphrase "secret" \
            --cert pki_int_v1.1.crt \
            "${COMMON_NAME} Intermediate CA v1.1"

cp ../pki_int_v1.1.crt .
            
./vault write -format=json \
        pki_int/intermediate/set-signed \
        issuer_name="vault-intermediate" \
        certificate=@pki_int_v1.1.crt \
        > pki_int_v1.1.set-signed.json

# ISSUER CERT
./vault write -format=json \
        pki_iss/intermediate/generate/internal \
        organization="${ORGANIZATION}" \
        common_name="${COMMON_NAME} Issuing CA v1.1.1" \
        issuer_name="vault-issuer" \
        key_bits=2048 \
        | ./jq -r '.data.csr' > pki_iss_v1.1.1.csr

./vault write -format=json \
        pki_int/root/sign-intermediate \
        organization="${ORGANIZATION}" \
        csr=@pki_iss_v1.1.1.csr \
        ttl=8760h \
        format=pem \
        | ./jq -r '.data.certificate' > pki_iss_v1.1.1.crt

# create cert chain
cat pki_iss_v1.1.1.crt pki_int_v1.1.crt > pki_iss_v1.1.1.chain.crt

./vault write -format=json \
      pki_iss/intermediate/set-signed \
      certificate=@pki_iss_v1.1.1.chain.crt \
      > pki_iss_v1.1.1.set-signed.json

# -----------------------------------------------------------------------
#  Generate PKI role
# -----------------------------------------------------------------------

./vault write pki_iss/roles/vault \
      organization="${ORGANIZATION}" \
      allowed_domains="${DOMAIN}" \
      allow_subdomains=true \
      allow_wildcard_certificates=false \
      require_cn=false \
      max_ttl=2160h


./vault policy write pki - <<EOF
path "pki*"                             { capabilities = ["read", "list"] }
path "pki_iss/sign/vault"               { capabilities = ["create", "update"] }
path "pki_iss/issue/vault"              { capabilities = ["create"] } 
EOF

# -----------------------------------------------------------------------
# Configure Kubernetes Authentication
# -----------------------------------------------------------------------
ISSUER_SA_REF="issuer"
ISSUER_SECRET_REF="issuer-token"

kubectl create serviceaccount ${ISSUER_SA_REF} --namespace ${NAMESPACE}

kubectl apply --filename - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${ISSUER_SECRET_REF}
  namespace: ${NAMESPACE}
  annotations:
    kubernetes.io/service-account.name: ${ISSUER_SA_REF}
type: kubernetes.io/service-account-token
EOF

./vault auth enable kubernetes

${VAULT_EXEC} -- sh -c 'vault write auth/kubernetes/config \
                token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
                kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
                kubernetes_host="https://${KUBERNETES_PORT_443_TCP_ADDR}:443"'

./vault write auth/kubernetes/role/issuer \
                  bound_service_account_names=${ISSUER_SA_REF} \
                  bound_service_account_namespaces=${NAMESPACE} \
                  policies=pki \
                  ttl=20m
set +x

# -----------------------------------------------------------------------
# Create cert folder and move certs
# -----------------------------------------------------------------------

mkdir ../certs
mv ./root ../certs
mv *.crt ../certs

# -----------------------------------------------------------------------
# git repo: https://github.com/cert-manager/cert-manager/tree/master/deploy/charts/cert-manager
# helm artifact: https://artifacthub.io/packages/helm/cert-manager/cert-manager
# -----------------------------------------------------------------------

CERT_MANAGER_VERSION="v1.12.1"

# Install cert-manager CRD's
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.crds.yaml

# install cert-manager
helm upgrade --install cert-manager jetstack/cert-manager --version ${CERT_MANAGER_VERSION} --namespace ${NAMESPACE} --create-namespace

# -----------------------------------------------------------------------
# Configure an issuer to generate a certificate
# -----------------------------------------------------------------------

kubectl apply --filename - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: vault-issuer
  namespace: ${NAMESPACE}
spec:
  vault:
    server: http://${LOCAL_HOSTNAME}
    path: pki_iss/sign/vault
    auth:
      kubernetes:
        mountPath: /v1/auth/kubernetes
        role: issuer
        secretRef:
          name: ${ISSUER_SECRET_REF}
          key: token
EOF

# -----------------------------------------------------------------------
# NOTES
# -----------------------------------------------------------------------

# EXAMPLES OF CREATING CERTS BESIDES INGRESS ANNOTATIONS

# kubectl apply --filename -<<EOF
# apiVersion: cert-manager.io/v1
# kind: Certificate
# metadata:
#   name: vault-cert
#   namespace: cert-manager
# spec:
#   secretName: vault.127.0.0.1.nip.io
#   issuerRef:
#     name: vault-issuer
#     kind: ClusterIssuer
#   commonName: "vault.127.0.0.1.nip.io"
#   dnsNames:
#   - "vault.127.0.0.1.nip.io"
# EOF

# ./vault write -format=json \
#       pki_iss/issue/vault \
#       common_name="sample.127.0.0.1.nip.io" \
#       > pki_iss_v1.1.1.sample.crt.json


# TO VIEW CERTIFICATE OBJECT

# kubectl get certificate -n cert-manager
# kubectl get certificaterequest -n cert-manager

# TO DELETE EVERYTHING

# kubectl delete clusterissuer vault-issuer
# helm uninstall vault -n cert-manager
# helm uninstall cert-manager -n cert-manager
# kubectl delete pvc data-vault-0 -n cert-manager 
# kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.12.1/cert-manager.crds.yaml
# kubectl delete ns cert-manager
# rm -rf tmp
# rm -rf certs

# TO ACCESS VAULT FROM TERMINAL

# export VAULT_SKIP_VERIFY=true
# export VAULT_ADDR="https://vault.127.0.0.1.nip.io"

# Look into using Vault as a kubernetes cert manager
# https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-cert-manager
# https://cert-manager.io/docs/configuration/vault/