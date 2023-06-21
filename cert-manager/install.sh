#!/bin/bash

# SETUP WAS DONE FOLLOWING THESE GUIDES:
# https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-cert-manager
# https://developer.hashicorp.com/vault/tutorials/secrets-management/pki-engine
# https://sestegra.medium.com/build-an-internal-pki-with-vault-f7179306f18c

# REQUIREMENTS:
#   - kubectl
#   - linux (amd64)

# import common functions and variables
. ../global_lib.sh
. ./lib/generate_certs.sh
. ./lib/install_tools.sh
. ./lib/setup_vault_pki.sh

# global
DEBUG=true
NAMESPACE="cert-manager"

# cert-manager variables
CERT_MANAGER_VERSION="v1.12.1"

# vault variables
HOSTNAME="vault.${DOMAIN}"
LOCAL_HOSTNAME="vault.${NAMESPACE}.svc.cluster.local:8200"

export VAULT_SKIP_VERIFY=true
export VAULT_ADDR="https://${HOSTNAME}"

# certs variables
ORGANIZATION="Wackyman"
COMMON_NAME="Wackyman"

setup_vault() {
  # vault init
  vault operator init -key-shares=1 \
                      -key-threshold=1 \
                      -format=json > keys.json

  # vault unseal
  VAULT_UNSEAL_KEY=$(cat keys.json | jq -r ".unseal_keys_b64[]")
  vault operator unseal ${VAULT_UNSEAL_KEY}

  # vault login
  VAULT_ROOT_TOKEN=$(cat keys.json | jq -r ".root_token")
  # local login
  vault login ${VAULT_ROOT_TOKEN}
  # remote login
  kubectl exec vault-0 --namespace ${NAMESPACE} -- vault login ${VAULT_ROOT_TOKEN}
}

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
countdown 15
echo ""

# delete tmp folder
rm -rf ./tmp

# create tmp folder
mkdir ./tmp && cd ./tmp

get_tools

echo ""
echo "-----------------------------------------------------------------------"
echo "SETTING UP ENVIRONMENT AND MAKING CERTS"
echo "-----------------------------------------------------------------------"

# get verbose logs
if ${DEBUG}
then
  set -x
fi

hide setup_vault --progress 0 20

# -----------------------------------------------------------------------
# Copy over cert inputs if any
# -----------------------------------------------------------------------

if [ -d ../input ]
then
  cp -r ../input/* .
fi

# -----------------------------------------------------------------------
# Configure PKI Secrets Engine - Enable pki secret engine
# -----------------------------------------------------------------------

hide enable_pki_engine --progress 20 40

# -----------------------------------------------------------------------
# Configure PKI Secrets Engine - Generate certificates
# -----------------------------------------------------------------------

hide generate_certs --progress 40 60

# -----------------------------------------------------------------------
#  Create PKI role
# -----------------------------------------------------------------------

hide create_pki_role --progress 60 80

# -----------------------------------------------------------------------
# Configure Kubernetes Authentication
# -----------------------------------------------------------------------

hide configure_k8_auth --progress 80 100

# -----------------------------------------------------------------------
# Create output folder and move all sensitive data to output folder
# -----------------------------------------------------------------------

# remove verbose logs
set +x
echo ""

mkdir output
mv keys.json ./output/
mv ./root/ ./output/
mv *.crt ./output

cp -r ./output/ ../

# -----------------------------------------------------------------------
# git repo: https://github.com/cert-manager/cert-manager/tree/master/deploy/charts/cert-manager
# helm artifact: https://artifacthub.io/packages/helm/cert-manager/cert-manager
# -----------------------------------------------------------------------

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
# Clean up
# -----------------------------------------------------------------------

cd .. && rm -rf tmp

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

# TO ACCESS VAULT FROM TERMINAL

# export VAULT_SKIP_VERIFY=true
# export VAULT_ADDR="https://vault.127.0.0.1.nip.io"

# EXAMPLE OF MANUAL CERTIFICATE GENERATION

# ./vault write -format=json \
#       pki_iss/issue/vault \
#       common_name="sample.127.0.0.1.nip.io" \
#       | ./jq -r '.data.certificate' > sample.crt

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
# rm -rf output

# Look into using Vault as a kubernetes cert manager
# https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-cert-manager
# https://cert-manager.io/docs/configuration/vault/