#!/bin/sh

# SETUP WAS DONE FOLLOWING THESE GUIDES:
# https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-cert-manager
# https://developer.hashicorp.com/vault/tutorials/secrets-management/pki-engine
# https://sestegra.medium.com/build-an-internal-pki-with-vault-f7179306f18c

# REQUIREMENTS:
#   - kubectl
#   - helm
#   - linux (amd64)

# -----------------------------------------------------------------------
# IMPORT LIBS
# -----------------------------------------------------------------------
EXE_DIR=$(dirname $(readlink -f $0))

. ${EXE_DIR}/../global_lib.sh
. ${EXE_DIR}/lib/install_tools.sh
. ${EXE_DIR}/lib/setup_vault_pki.sh
. ${EXE_DIR}/lib/generate_certs.sh

# -----------------------------------------------------------------------
# FUNCTIONS/METHODS
# -----------------------------------------------------------------------
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
# VARIABLES
# -----------------------------------------------------------------------
# global
DEBUG=true
NAMESPACE="cert-manager"

# cert-manager variables
CERT_MANAGER_VERSION="v1.12.1"

# vault variables
VAULT_VERSION=""
HOSTNAME="vault.${DOMAIN}"
LOCAL_HOSTNAME="vault.${NAMESPACE}.svc.cluster.local:8200"

export VAULT_SKIP_VERIFY=true
export VAULT_ADDR="https://${HOSTNAME}"

# certificate variables
ORGANIZATION="Private"
COMMON_NAME="Private"

# issuer reference variables
SETUP_PUBLIC_PKI=true
SETUP_PRIVATE_PKI=true
PUBLIC_ISSUER="vault-public-issuer"
PRIVATE_ISSUER="vault-private-issuer"

# -----------------------------------------------------------------------
# HELM REPO
# -----------------------------------------------------------------------
helm repo add jetstack https://charts.jetstack.io
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# -----------------------------------------------------------------------
# CREATE CACHE FOLDER
# -----------------------------------------------------------------------

# delete tmp folder
rm -rf ./tmp

# create tmp folder
mkdir ./tmp && cd ./tmp

# -----------------------------------------------------------------------
# INSTALL VAULT
# -----------------------------------------------------------------------

# git repo: https://github.com/hashicorp/vault-helm/blob/main/values.yaml
# helm artifact: https://artifacthub.io/packages/helm/hashicorp/vault

echo ""
echo "-----------------------------------------------------------------------"
echo "INSTALLING VAULT"
echo "-----------------------------------------------------------------------"
echo ""

# install vault with helm
helm upgrade --install vault hashicorp/vault --namespace ${NAMESPACE} --create-namespace \
             --set server.ingress.enabled=true \
             --set server.ingress.hosts[0].host=${HOSTNAME} \
             --set server.ingress.tls[0].secretName=${HOSTNAME} \
             --set server.ingress.tls[0].hosts[0]=${HOSTNAME} \
             --set injector.enabled=false

# update ingress annotation to generate kubernetes certificate object when cert-manager is set up
kubectl annotate ing vault -n ${NAMESPACE} \
        --overwrite cert-manager.io/cluster-issuer="${PUBLIC_ISSUER}" \
        cert-manager.io/common-name="${HOSTNAME}"

# wait for vault to be ready
countdown 15

echo ""
echo "-----------------------------------------------------------------------"
echo "UNSEAL AND LOGIN TO VAULT"
echo "-----------------------------------------------------------------------"
echo ""

# Download missing tools into bin folder
hide get_tools --progress 0 30

# init, unseal and login to vault
hide setup_vault --progress 30 70

# configure kubernetes authentication
hide configure_k8_auth --progress 70 100

# -----------------------------------------------------------------------
# INSTALL CERT-MANAGER
# -----------------------------------------------------------------------

# git repo: https://github.com/cert-manager/cert-manager/tree/master/deploy/charts/cert-manager
# helm artifact: https://artifacthub.io/packages/helm/cert-manager/cert-manager

echo ""
echo "-----------------------------------------------------------------------"
echo "INSTALLING CERT-MANAGER"
echo "-----------------------------------------------------------------------"
echo ""

# Install cert-manager CRD's
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.crds.yaml

# install cert-manager
helm upgrade --install cert-manager jetstack/cert-manager --version ${CERT_MANAGER_VERSION} --namespace ${NAMESPACE} --create-namespace

# -----------------------------------------------------------------------
# SETUP PKI ENGINE - PUBLIC
# -----------------------------------------------------------------------

if ${SETUP_PUBLIC_PKI}
then
  echo ""
  echo "-----------------------------------------------------------------------"
  echo "SETTING UP PUBLIC PKI ENGINE"
  echo "-----------------------------------------------------------------------"
  echo ""

  # enable pki secret engine
  hide enable_public_pki_engine --progress 0 20

  # create pki role
  hide create_public_pki_role --progress 20 40

  # create k8 issuer resource
  hide create_public_k8_issuer --progress 60 80

  # generate intermediate csr to be signed by an authority
  hide generate_public_intermediate_csr --progress 80 100
fi

# -----------------------------------------------------------------------
# SETUP PKI ENGINE - PRIVATE
# -----------------------------------------------------------------------

if ${SETUP_PRIVATE_PKI}
then
  echo ""
  echo "-----------------------------------------------------------------------"
  echo "SETTING UP PRIVATE PKI ENGINE"
  echo "-----------------------------------------------------------------------"
  echo ""

  # enable pki secret engine
  hide enable_private_pki_engine --progress 0 20

  # create pki role
  hide create_private_pki_role --progress 20 40
  
  # create k8 issuer resource
  hide create_private_k8_issuer --progress 40 60

  # generate certificates (only possible with internal certificates)
  hide generate_private_certs --progress 60 100
fi

# when the certmanager takes too long to start the initial certificate request times out
# deleting it would force an automatic recreate
kubectl delete certificate ${HOSTNAME} --namespace ${NAMESPACE} > /dev/null 2>&1

# -----------------------------------------------------------------------
# STORE CERTIFICATES AND SENSITIVE INFO IN OUTPUT FOLDER
# -----------------------------------------------------------------------

mkdir -p output/private
mkdir -p output/public
mkdir -p output/auth

mv keys.json ./output/auth/
mv pri_*.crt ./output/private/
cp ./pub_pki_int.csr ./output/public/

mv ./output ..


echo ""
echo "-----------------------------------------------------------------------"
echo "INFO"
echo "-----------------------------------------------------------------------"
echo ""
echo "If you are using a public authority, go to the './outputs/public/' folder and sign the csr with a public authority."
echo "After that copy the resulting certificate to ./outputs/public/ and make sure it is named 'pub_pki_int.crt'"
echo "Then you can run './generate_public_certs.sh'."
echo ""
echo ""
echo "vault url: https://${HOSTNAME}"


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
#   secretName: test.127.0.0.1.nip.io
#   issuerRef:
#     name: vault-public-issuer
#     kind: ClusterIssuer
#   commonName: "test.127.0.0.1.nip.io"
#   dnsNames:
#   - "test.127.0.0.1.nip.io"
# EOF

# TO ACCESS VAULT FROM TERMINAL

# export VAULT_SKIP_VERIFY=true
# export VAULT_ADDR="https://vault.127.0.0.1.nip.io"

# SET TEMP PATH FOR EXECUTABLES

# PATH=${PATH}:$(pwd)/tmp/bin

# EXAMPLE OF MANUAL CERTIFICATE GENERATION

# vault write -format=json \
#       pki_iss/issue/vault \
#       common_name="sample.127.0.0.1.nip.io" \
#       | ./jq -r '.data.certificate' > sample.crt

# TO VIEW CERTIFICATE OBJECT

# kubectl get certificate -n cert-manager
# kubectl get certificaterequest -n cert-manager

# TO DELETE EVERYTHING

# kubectl delete clusterissuer vault-private-issuer
# kubectl delete clusterissuer vault-public-issuer
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