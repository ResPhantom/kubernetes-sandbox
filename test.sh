#!/bin/sh

# . ./global_lib.sh

# wait ping fart

# DEBUG=true

# export VAULT_SKIP_VERIFY=true
# export VAULT_ADDR="https://vault.127.0.0.1.nip.io"

# ./cert-manager/vault list pki

# progress_instance() {
#   percentage=$1
#   calculation=$((50 - (${percentage} % 2)))
#   replace="\033[1A\033[K"
#   bar=""

#   for i in $(seq ${percentage} -1 1); do
#     bar="${bar}."
#   done
  
#   echo "${replace}${percentage}%${bar}"
# }

# progress_bar() {
#   percentage_begin=$1
#   percentage_end=$2

#   for i in $(seq ${percentage_begin} 1 ${percentage_end}); do
#     progress_instance $i
#     sleep 0.02
#   done
# }

# bruh=true
# HIDE=``

# cat test > /dev/null 2>&1
# echo []

# progress_instance 80

# hide "sleep 2;echo p" --progress 0 20
# hide "sleep 1;echo e" --progress 20 40
# hide "sleep 5;echo n" --progress 40 60
# hide "sleep 2;echo i" --progress 60 80
# hide "sleep 1;echo s" --progress 80 100
# echo ""

# countdown 10

# if ${bruh};then ;fi

# countdown 10
ls $0

../bin/certstrap --depot-path root init \
          --organization "${ORGANIZATION}" \
          --common-name "${COMMON_NAME} Root CA ${current_time}" \
          --expires "10 years" \
          --curve P-256 \
          --path-length 2 \
          --passphrase "secret"