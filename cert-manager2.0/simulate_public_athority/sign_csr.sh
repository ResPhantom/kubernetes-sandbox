#!/bin/sh

ORGANIZATION="Public Athority"
COMMON_NAME="Public Athority"

CURRENT_TIME=$(date +%d_%b_%Y.%H-%M-%S)

mv ./csr_input/* .

../bin/certstrap --depot-path root sign \
                --CA "${COMMON_NAME} Root CA 2023" \
                --intermediate \
                --csr pub_pki_int.csr \
                --expires "5 years" \
                --path-length 1 \
                --passphrase "secret" \
                --cert pub_pki_int.crt \
                "${COMMON_NAME} Intermediate CA ${CURRENT_TIME}"

# make an output folder and a public folder if it does not exist
mkdir -p ../output/public

# copy root to public output folder
cp ./root/*.crt ../output/public/pub_pki_root.crt
mv -f ./*.crt ../output/public/

# cleanup
rm -rf ./csr_input/*.csr
rm *.csr