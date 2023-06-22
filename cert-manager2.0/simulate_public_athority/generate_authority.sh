#!/bin/sh

ORGANIZATION="Public Athority"
COMMON_NAME="Public Athority"

CURRENT_TIME=$(date +%Y)

../bin/certstrap --depot-path root init \
              --organization "${ORGANIZATION}" \
              --common-name "${COMMON_NAME} Root CA ${CURRENT_TIME}" \
              --expires "30 years" \
              --curve P-256 \
              --path-length 2 \
              --passphrase "secret"
