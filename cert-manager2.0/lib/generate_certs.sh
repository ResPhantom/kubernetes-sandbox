#!/bin/sh
generate_public_intermediate_csr() {
  vault write -format=json \
          pub_pki_int/intermediate/generate/internal \
          organization="${ORGANIZATION}" \
          common_name="${COMMON_NAME} Intermediate CA ${CURRENT_TIME}" \
          key_bits=4096 \
          | jq -r '.data.csr' > pub_pki_int.csr
}

# generates pri_pki_int issuer certificate, requires a signed intermediate cert to work
generate_public_intermediate_cert() {
  vault write -format=json \
        pub_pki_int/intermediate/set-signed \
        certificate=@pub_pki_int.crt \
        > pub_pki_int.set-signed.json

  # set intermediate issuer_name
  issuer_ref=$(cat pub_pki_int.set-signed.json | jq -r '.data.imported_issuers[0]')

  vault write -format=json \
        pub_pki_int/issuer/${issuer_ref} \
        issuer_name=${CURRENT_TIME} \
        > pub_pki_int.issuer_name.json
}

# generates pub_pki_iss issuer certificate, requires pub_pki_int in order to work
generate_public_issuer_cert() {
  vault write -format=json \
        pub_pki_iss/intermediate/generate/internal \
        organization="${ORGANIZATION}" \
        common_name="${COMMON_NAME} Issuing CA ${CURRENT_TIME}" \
        key_bits=2048 \
        | jq -r '.data.csr' > pub_pki_iss.csr

  vault write -format=json \
        pub_pki_int/root/sign-intermediate \
        organization="${ORGANIZATION}" \
        csr=@pub_pki_iss.csr \
        ttl=8760h \
        format=pem \
        | jq -r '.data.certificate' > pub_pki_iss.crt

  # create cert chain
  cat pub_pki_iss.crt pub_pki_int.crt > pub_pki_iss.chain.crt

  vault write -format=json \
        pub_pki_iss/intermediate/set-signed \
        certificate=@pub_pki_iss.chain.crt \
        > pub_pki_iss.set-signed.json

  # set issuer issuer_name
  issuer_ref=$(cat pub_pki_iss.set-signed.json | jq -r '.data.imported_issuers[0]')

  vault write -format=json \
        pub_pki_iss/issuer/${issuer_ref} \
        issuer_name=${CURRENT_TIME} \
        > pub_pki_iss.issuer_name.json
}

# generates pri_pki issuer certificate
generate_private_root_cert() {
  vault write -field=certificate \
        pri_pki/root/generate/internal \
        organization="${ORGANIZATION}" \
        common_name="${COMMON_NAME} Root CA ${CURRENT_TIME}" \
        issuer_name="${CURRENT_TIME}" \
        ttl=87600h > pri_pki_root.crt
}

# generates pri_pki_int issuer certificate, requires pri_pki in order to work
generate_private_intermediate_cert() {
  vault write -format=json \
        pri_pki_int/intermediate/generate/internal \
        organization="${ORGANIZATION}" \
        common_name="${COMMON_NAME} Intermediate CA ${CURRENT_TIME}" \
        key_bits=4096 \
        | jq -r '.data.csr' > pri_pki_int.csr

  vault write -format=json \
        pri_pki/root/sign-intermediate \
        organization="${ORGANIZATION}" \
        csr=@pri_pki_int.csr \
        ttl=43800h \
        format=pem \
        | jq -r '.data.certificate' > pri_pki_int.crt
  
  vault write -format=json \
        pri_pki_int/intermediate/set-signed \
        certificate=@pri_pki_int.crt \
        > pri_pki_int.set-signed.json

  # set intermediate issuer_name
  issuer_ref=$(cat pri_pki_int.set-signed.json | jq -r '.data.imported_issuers[0]')

  vault write -format=json \
        pri_pki_int/issuer/${issuer_ref} \
        issuer_name=${CURRENT_TIME} \
        > pri_pki_int.issuer_name.json
}

# generates pri_pki_iss issuer certificate, requires pri_pki_int in order to work
generate_private_issuer_cert() {
  vault write -format=json \
        pri_pki_iss/intermediate/generate/internal \
        organization="${ORGANIZATION}" \
        common_name="${COMMON_NAME} Issuing CA ${CURRENT_TIME}" \
        key_bits=2048 \
        | jq -r '.data.csr' > pri_pki_iss.csr

  vault write -format=json \
        pri_pki_int/root/sign-intermediate \
        organization="${ORGANIZATION}" \
        csr=@pri_pki_iss.csr \
        ttl=8760h \
        format=pem \
        | jq -r '.data.certificate' > pri_pki_iss.crt

  # create cert chain
  cat pri_pki_iss.crt pri_pki_int.crt > pri_pki_iss.chain.crt

  vault write -format=json \
        pri_pki_iss/intermediate/set-signed \
        certificate=@pri_pki_iss.chain.crt \
        > pri_pki_iss.set-signed.json

  # set issuer issuer_name
  issuer_ref=$(cat pri_pki_iss.set-signed.json | jq -r '.data.imported_issuers[0]')

  vault write -format=json \
        pri_pki_iss/issuer/${issuer_ref} \
        issuer_name=${CURRENT_TIME} \
        > pri_pki_iss.issuer_name.json
}

generate_private_certs() {
  generate_private_root_cert
  generate_private_intermediate_cert
  generate_private_issuer_cert
}

# rotate_root_certificate() {

# }

# rotate_int_certificate() {

# }

# rotate_iss_certificate() {

# }

ORGANIZATION="${ORGANIZATION:=vault}"
COMMON_NAME="${COMMON_NAME:=vault}"
CURRENT_TIME=$(date +%d_%b_%Y.%H-%M-%S)