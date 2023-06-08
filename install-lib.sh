#!/bin/sh

# Set global variables here
export DOMAIN="${DOMAIN:=127.0.0.1.nip.io}"



# Fixing kubeconfig permissions just in case, mainly to get rid of annoying warnings
chmod 600 ~/.kube/config

# Below you can add more repo commands. The following command '$() > /dev/null 2>&1' is just to silence annoying output
$(

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx;
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/;
helm repo add jetstack https://charts.jetstack.io;
helm repo add hashicorp https://helm.releases.hashicorp.com;

) > /dev/null 2>&1

helm repo update

