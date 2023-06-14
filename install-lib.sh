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

progress_instance() {
  percentage=$1
  calculation=$((50 - (${percentage} % 2)))
  replace="\033[1A\033[K"
  bar=""

  for i in $(seq ${percentage} -1 1); do
    bar="${bar}."
  done
  
  echo -e "${replace}${percentage}%${bar}"
}

progress_bar() {
  percentage_begin=$1
  percentage_end=$2
  for i in $(seq ${percentage_begin} 1 ${percentage_end}); do
    progress_instance $i
    sleep 0.02
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