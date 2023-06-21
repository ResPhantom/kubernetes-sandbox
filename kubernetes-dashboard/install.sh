#!/bin/sh
# git repo: https://github.com/kubernetes/dashboard
# helm artifact: https://artifacthub.io/packages/helm/k8s-dashboard/kubernetes-dashboard

. ../global_lib.sh

helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard \
             --namespace kubernetes-dashboard \
             --create-namespace \
             --set ingress.enabled=true \
             --set ingress.hosts[0]=kubernetes-dashboard.${DOMAIN}
            #  --set metricsScraper.enabled=true \
            #  --set metrics-server.enabled=true
             