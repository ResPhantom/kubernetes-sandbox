#!/bin/sh

get_tools() {
  mkdir bin
  cd bin

  # get tools
  kubectl cp ${NAMESPACE}/vault-0:/bin/vault ./vault
  curl -SL https://github.com/jqlang/jq/releases/download/jq-1.6/jq-linux32 -o jq
  cp ${LIB_DIR}/certstrap .

  # set execution permissions
  chmod 555 vault jq certstrap

  PATH=${PATH}:$(pwd)

  cd ..
}

LIB_DIR="${PWD}/lib"