#!/bin/sh

generate_certs_root_outside() {
  current_time=$(date +%d_%b_%Y.%H-%M-%S)

  # ROOT CERT
  if [ ! -d root ]
  then
    certstrap --depot-path root init \
              --organization "${ORGANIZATION}" \
              --common-name "${COMMON_NAME} Root CA ${current_time}" \
              --expires "10 years" \
              --curve P-256 \
              --path-length 2 \
              --passphrase "secret"
  fi

  if [ ! -f "pki_int.crt" ]
  then
  # INTERMEDIATE CERT
    vault write -format=json \
          pki_int/intermediate/generate/internal \
          organization="${ORGANIZATION}" \
          common_name="${COMMON_NAME} Intermediate CA ${current_time}" \
          key_bits=4096 \
          | jq -r '.data.csr' > pki_int.csr

    certstrap --depot-path root sign \
              --CA "${COMMON_NAME} Root CA ${current_time}" \
              --intermediate \
              --csr pki_int.csr \
              --expires "5 years" \
              --path-length 1 \
              --passphrase "secret" \
              --cert pki_int.crt \
              "${COMMON_NAME} Intermediate CA ${current_time}"
                
    vault write -format=json \
          pki_int/intermediate/set-signed \
          certificate=@pki_int.crt \
          > pki_int.set-signed.json

    # set intermediate issuer_name
    issuer_ref=$(cat pki_int.set-signed.json | jq -r '.data.imported_issuers[0]')

    vault write -format=json \
          pki_int/issuer/${issuer_ref} \
          issuer_name=${current_time} \
          > pki_int.issuer_name.json
  fi

  # ISSUER CERT
  vault write -format=json \
        pki_iss/intermediate/generate/internal \
        organization="${ORGANIZATION}" \
        common_name="${COMMON_NAME} Issuing CA ${current_time}" \
        key_bits=2048 \
        | jq -r '.data.csr' > pki_iss.csr

  vault write -format=json \
        pki_int/root/sign-intermediate \
        organization="${ORGANIZATION}" \
        csr=@pki_iss.csr \
        ttl=8760h \
        format=pem \
        | jq -r '.data.certificate' > pki_iss.crt

  # create cert chain
  cat pki_iss.crt pki_int.crt > pki_iss.chain.crt

  vault write -format=json \
        pki_iss/intermediate/set-signed \
        certificate=@pki_iss.chain.crt \
        > pki_iss.set-signed.json
  
  # set issuer issuer_name
  issuer_ref=$(cat pki_iss.set-signed.json | jq -r '.data.imported_issuers[0]')

  vault write -format=json \
        pki_iss/issuer/${issuer_ref} \
        issuer_name=${current_time} \
        > pki_iss.issuer_name.json
}

generate_certs() {
  current_time=$(date +%d_%b_%Y.%H-%M-%S)

  # ROOT CERT
  vault write -field=certificate \
        pki/root/generate/internal \
        organization="${ORGANIZATION}" \
        common_name="${COMMON_NAME} Root CA ${current_time}" \
        issuer_name="${current_time}" \
        ttl=87600h > pki_root.crt

  # INTERMEDIATE CERT
  vault write -format=json \
        pki_int/intermediate/generate/internal \
        organization="${ORGANIZATION}" \
        common_name="${COMMON_NAME} Intermediate CA ${current_time}" \
        key_bits=4096 \
        | jq -r '.data.csr' > pki_int.csr

  vault write -format=json \
        pki/root/sign-intermediate \
        organization="${ORGANIZATION}" \
        csr=@pki_int.csr \
        ttl=43800h \
        format=pem \
        | jq -r '.data.certificate' > pki_int.crt
  
  vault write -format=json \
        pki_int/intermediate/set-signed \
        certificate=@pki_int.crt \
        > pki_int.set-signed.json

  # set intermediate issuer_name
  issuer_ref=$(cat pki_int.set-signed.json | jq -r '.data.imported_issuers[0]')

  vault write -format=json \
        pki_int/issuer/${issuer_ref} \
        issuer_name=${current_time} \
        > pki_int.issuer_name.json

  # ISSUER CERT
  vault write -format=json \
        pki_iss/intermediate/generate/internal \
        organization="${ORGANIZATION}" \
        common_name="${COMMON_NAME} Issuing CA ${current_time}" \
        key_bits=2048 \
        | jq -r '.data.csr' > pki_iss.csr

  vault write -format=json \
        pki_int/root/sign-intermediate \
        organization="${ORGANIZATION}" \
        csr=@pki_iss.csr \
        ttl=8760h \
        format=pem \
        | jq -r '.data.certificate' > pki_iss.crt

  # create cert chain
  cat pki_iss.crt pki_int.crt > pki_iss.chain.crt

  vault write -format=json \
        pki_iss/intermediate/set-signed \
        certificate=@pki_iss.chain.crt \
        > pki_iss.set-signed.json

  # set issuer issuer_name
  issuer_ref=$(cat pki_iss.set-signed.json | jq -r '.data.imported_issuers[0]')

  vault write -format=json \
        pki_iss/issuer/${issuer_ref} \
        issuer_name=${current_time} \
        > pki_iss.issuer_name.json
}

# rotate_root_certificate() {

# }

# rotate_int_certificate() {

# }

# rotate_iss_certificate() {

# }

ORGANIZATION="${ORGANIZATION:=vault}"
COMMON_NAME="${COMMON_NAME:=vault}"