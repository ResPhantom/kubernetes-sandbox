#!/bin/sh

get_tools() {
  mkdir bin
  cd bin

  # get specfic version vault cli tool from vault deployment
  kubectl cp ${NAMESPACE}/vault-0:/bin/vault ./vault

  # download jq
  curl -SL https://github.com/jqlang/jq/releases/download/jq-1.6/jq-linux32 -o jq

  # set execution permissions
  chmod 555 vault jq

  # Temporarily set tools PATH for execution
  PATH=${PATH}:$(pwd)

  cd ..
}