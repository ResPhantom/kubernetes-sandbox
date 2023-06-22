#!/bin/sh

# SETUP WAS DONE FOLLOWING THESE GUIDE(S):
# https://medium.com/@muhammadbilalparacha/2048-game-deployment-on-kubernetes-2e0a13f93599

# import common functions and variables
. ../global_lib.sh

NAMESPACE="dummy-2048"
HOSTNAME="dummy.${DOMAIN}"

helm upgrade --install dummy-2048 ./helm --namespace ${NAMESPACE} --create-namespace \
             -f values-prod.yaml

# -----------------------------------------------------------------------
# NOTES
# -----------------------------------------------------------------------

echo ""
echo "dummy url: ${HOSTNAME}"

# ALTERNATIVE DEPLOY

# kubectl apply -f deploy.yaml

# TO DELETE

# helm uninstall dummy-2048 -n dummy-2048
# kubectl delete ns dummy-2048