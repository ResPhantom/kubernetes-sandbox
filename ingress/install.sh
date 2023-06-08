#!/bin/sh
# git repo: https://github.com/kubernetes/ingress-nginx
# helm artifact: https://artifacthub.io/packages/helm/ingress-nginx/ingress-nginx

$(dirname $(readlink -f $0))/../install-lib.sh

helm upgrade --install app-ingress ingress-nginx/ingress-nginx \
             --namespace ingress \
             --create-namespace \
             --set controller.ingressClassResource.default=true