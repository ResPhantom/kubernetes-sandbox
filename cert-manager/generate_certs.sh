#!/bin/sh

# create tmp folder
mkdir ./tmp && cd ./tmp

cp ../certstrap .

./certstrap --depot-path root init \
            --organization "Example" \
            --common-name "Example Labs Root CA v1" \
            --expires "10 years" \
            --curve P-256 \
            --path-length 2 \
            --passphrase "secret"