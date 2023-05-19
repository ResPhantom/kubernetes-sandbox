#!/bin/sh
HOSTNAME='master-1'

hostname $HOSTNAME
echo $HOSTNAME > /etc/hostname

# Create master node and subnet
kubeadm init --pod-network-cidr=10.244.0.0/16 --node-name=$(hostname) --ignore-preflight-errors=all

# Symlink Kubectl config and set up network
mkdir ~/.kube
ln -s /etc/kubernetes/admin.conf /root/.kube/config
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

# Generate worker node join command
kubeadm token create --print-join-command >> /mnt/shared/join.sh