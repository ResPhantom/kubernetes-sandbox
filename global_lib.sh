#!/bin/sh

# Set global variables here
DOMAIN="${DOMAIN:=127.0.0.1.nip.io}"
DEBUG=false

# countdown to wait for something in a timely manner
countdown() {
  # replace="\033[1A\033[K"
  countdown="${1:='5'}"
  wait_message="Waiting for "

  printf "${wait_message} $countdown."

  for i in $(seq ${countdown} -1 1)
  do 
      printf "\r                   "
      printf "\r${wait_message} $i."
      sleep 0.2
      printf "\r${wait_message} $i.."
      sleep 0.3
      printf "\r${wait_message} $i..."
      sleep 0.3
  done
}

# prints out a instance of a progress bar
progress_instance() {
  percentage=$1
  printed_char="|"
  calculation=$((50 - (${percentage} % 2)))
  # echo ${calcultion}
  bar=""

  for i in $(seq ${percentage} -1 1); do
    bar="${bar}${printed_char}"
  done
  
  echo "${percentage}%%${bar}"
}

# This bar loops through two values and prints out a progress_bar animation using the progress_instance
progress_bar() {
  percentage_begin=$1
  percentage_end=$2
  for i in $(seq ${percentage_begin} 1 ${percentage_end}); do
    printf "\r$(progress_instance $i)"
    sleep 0.01
  done
}

# This command hides the output of various commands and replace them with an optional progress bar.
# This is mainly to hide sensitive or annoying information/output
hide() {
  if ${DEBUG}
  then
    set -x
    $1
    set +x
  else
    $1 > /dev/null 2>&1
    shift
    if [ ! -z $1 ] && [ $1 = "--progress" ]
      then
        shift
        progress_bar $1 $2
      fi
  fi
}

# Below you can add more repo commands. 
add_helm_repos() {
  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
  helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
  helm repo add jetstack https://charts.jetstack.io
  helm repo add hashicorp https://helm.releases.hashicorp.com
  
  helm repo update
}

hide add_helm_repos


# Fixing kubeconfig permissions just in case, mainly to get rid of annoying warnings
chmod 600 ~/.kube/config