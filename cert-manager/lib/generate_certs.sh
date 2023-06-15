#!/bin/sh

generate_certs_root_outside() {
  # ROOT CERT
  if [ ! -d root ]
  then
    certstrap --depot-path root init \
              --organization "${ORGANIZATION}" \
              --common-name "${COMMON_NAME} Root CA" \
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
          common_name="${COMMON_NAME} Intermediate CA" \
          issuer_name="vault-intermediate" \
          key_bits=4096 \
          | jq -r '.data.csr' > pki_int.csr

    certstrap --depot-path root sign \
              --CA "${COMMON_NAME} Root CA" \
              --intermediate \
              --csr pki_int.csr \
              --expires "5 years" \
              --path-length 1 \
              --passphrase "secret" \
              --cert pki_int.crt \
              "${COMMON_NAME} Intermediate CA"
                
    vault write -format=json \
          pki_int/intermediate/set-signed \
          issuer_name="vault-intermediate" \
          certificate=@pki_int.crt \
          > pki_int.set-signed.json
  fi

  # ISSUER CERT
  vault write -format=json \
        pki_iss/intermediate/generate/internal \
        organization="${ORGANIZATION}" \
        common_name="${COMMON_NAME} Issuing CA" \
        issuer_name="vault-issuer" \
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
}

generate_certs() {
  # ROOT CERT
  vault write -field=certificate \
        pki/root/generate/internal \
        organization="${ORGANIZATION}" \
        common_name="${COMMON_NAME} Root CA" \
        issuer_name="vault-root" \
        ttl=87600h > pki_root.crt

  # INTERMEDIATE CERT
  vault write -format=json \
        pki_int/intermediate/generate/internal \
        organization="${ORGANIZATION}" \
        common_name="${COMMON_NAME} Intermediate CA" \
        issuer_name="vault-intermediate" \
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
        issuer_name="vault-intermediate" \
        certificate=@pki_int.crt \
        > pki_int.set-signed.json

  # ISSUER CERT
  vault write -format=json \
        pki_iss/intermediate/generate/internal \
        organization="${ORGANIZATION}" \
        common_name="${COMMON_NAME} Issuing CA" \
        issuer_name="vault-issuer" \
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
}

ORGANIZATION="${ORGANIZATION:=vault}"
COMMON_NAME="${COMMON_NAME:=vault}"