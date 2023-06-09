#!/bin/sh
# git repo: https://github.com/kubernetes/ingress-nginx
# helm artifact: https://artifacthub.io/packages/helm/ingress-nginx/ingress-nginx

. $(dirname $(readlink -f $0))/../install-lib.sh

helm upgrade --install app-ingress ingress-nginx/ingress-nginx \
             --namespace ingress \
             --create-namespace \
             --set controller.ingressClassResource.default=true

# In case your ingress service external IP is in a <pending> state:
# Run the following command for Linux: 
# dhclient -r

# Run the following command for Windows:
# ipconfig /renew

# restart kubernetes cluster
# restart wsl - wsl --shutdown
# let your PC go to sleep for 5 sec
# restart your machine