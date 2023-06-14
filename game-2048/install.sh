#!/bin/sh

# SETUP WAS DONE FOLLOWING THESE GUIDE(S):
# https://medium.com/@muhammadbilalparacha/2048-game-deployment-on-kubernetes-2e0a13f93599

# import common functions and variables
. $(dirname $(readlink -f $0))/../install-lib.sh

NAMESPACE="game-2048"
HOSTNAME="game.${DOMAIN}"

helm upgrade --install game-2048 ./helm --namespace ${NAMESPACE} --create-namespace \
             --set ingress.host=${HOSTNAME}

# -----------------------------------------------------------------------
# NOTES
# -----------------------------------------------------------------------

# ALTERNATIVE DEPLOY

# kubectl apply -f deploy.yaml

# TO DELETE

# kubectl delete ns game-2048