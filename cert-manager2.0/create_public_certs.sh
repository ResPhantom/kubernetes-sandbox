#!/bin/sh

# -----------------------------------------------------------------------
# IMPORT LIBS
# -----------------------------------------------------------------------

EXE_DIR=$(dirname $(readlink -f $0))

. ${EXE_DIR}/../global_lib.sh
. ${EXE_DIR}/lib/generate_certs.sh
. ${EXE_DIR}/lib/install_tools.sh
. ${EXE_DIR}/lib/setup_vault_pki.sh

# -----------------------------------------------------------------------
# VARIABLES
# -----------------------------------------------------------------------

# global
DEBUG=true
NAMESPACE="cert-manager"

# vault variables
HOSTNAME="vault.${DOMAIN}"
LOCAL_HOSTNAME="vault.${NAMESPACE}.svc.cluster.local:8200"

export VAULT_SKIP_VERIFY=true
export VAULT_ADDR="https://${HOSTNAME}"

# certificate variables
ORGANIZATION="Public"
COMMON_NAME="Public"

# -----------------------------------------------------------------------
# CREATE CACHE FOLDER & INSTALL TOOLS
# -----------------------------------------------------------------------

# delete tmp folder
rm -rf ./tmp

# create tmp folder
mkdir ./tmp && cd ./tmp

# Download missing tools into bin folder
hide get_tools

# -----------------------------------------------------------------------
# LOGIN & MOVE PUBLIC INTERMEDIATE CERT TO TEMP FOLDER
# -----------------------------------------------------------------------

# vault login
VAULT_ROOT_TOKEN=$(cat ../output/auth/keys.json | jq -r ".root_token")
hide $(vault login ${VAULT_ROOT_TOKEN})

cp ../output/public/pub_pki_int.crt .

# -----------------------------------------------------------------------
# GENERATE PUBLIC CERTIFICATES
# -----------------------------------------------------------------------

echo ""
echo "-----------------------------------------------------------------------"
echo "INSTALLING CERTS TO PUBLIC PKI ENGINE"
echo "-----------------------------------------------------------------------"
echo ""

hide generate_public_intermediate_cert --progress 0 50

hide generate_public_issuer_cert --progress 50 100

mv -f *.crt ../output/public/

# when the certmanager takes too long to start the initial certificate request times out
# deleting it would force an automatic recreate
kubectl delete certificate ${HOSTNAME} --namespace ${NAMESPACE} > /dev/null 2>&1