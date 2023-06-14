#!/bin/sh
. $(dirname $(readlink -f $0))/install-lib.sh

# wait ping fart


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

bruh=true
HIDE=``

cat test > /dev/null 2>&1
echo []


countdown 10

if ${bruh};then progress_bar 20 40;fi

