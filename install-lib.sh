#!/bin/sh

# Set global variables here
export DOMAIN="${DOMAIN:=127.0.0.1.nip.io}"

countdown() {
  # Countdown for reboot to use new Linux Kernel version
  replace="\033[1A\033[K"
  countdown="${1:='5'}"
  wait_message="Waiting for "

  echo "${wait_message} $i."

  for i in $(seq ${countdown} -1 1)
  do 
      echo -e "${replace}${wait_message} $i."
      sleep 0.2
      echo -e "${replace}${wait_message} $i.."
      sleep 0.3
      echo -e "${replace}${wait_message} $i..."
      sleep 0.3
  done
}

# Below you can add more repo commands. The following command '$() > /dev/null 2>&1' is just to silence annoying output
add_helm_repos() {
  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
  helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
  helm repo add jetstack https://charts.jetstack.io
  helm repo add hashicorp https://helm.releases.hashicorp.com
}

add_helm_repos > /dev/null 2>&1
helm repo update

# Fixing kubeconfig permissions just in case, mainly to get rid of annoying warnings
chmod 600 ~/.kube/config