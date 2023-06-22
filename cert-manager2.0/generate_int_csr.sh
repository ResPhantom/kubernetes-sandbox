#!/bin/sh

# -----------------------------------------------------------------------
# IMPORT LIBS
# -----------------------------------------------------------------------

EXE_DIR=$(dirname $(readlink -f $0))

. ${EXE_DIR}/../global_lib.sh
. ${EXE_DIR}/lib/generate_certs.sh
. ${EXE_DIR}/lib/install_tools.sh

# -----------------------------------------------------------------------
# VARIABLES
# -----------------------------------------------------------------------

# global
DEBUG=false
NAMESPACE="cert-manager"
CURRENT_TIME=$(date +%d_%b_%Y.%H-%M-%S)

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
# LOGIN AND GENERATE CSR
# -----------------------------------------------------------------------

# vault login
VAULT_ROOT_TOKEN=$(cat ../output/auth/keys.json | jq -r ".root_token")
hide $(vault login ${VAULT_ROOT_TOKEN})

hide generate_public_intermediate_csr --progress 0 100

cat pub_pki_int.csr

# -----------------------------------------------------------------------
# MOVE OUTPUT CLEAN CACHE
# -----------------------------------------------------------------------

# make an output folder and a public folder if it does not exist
mkdir -p ../output/public

cp ./pub_pki_int.csr ../output/public/

cd .. 
rm -rf ./tmp