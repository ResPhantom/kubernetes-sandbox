#!/bin/sh
HOSTNAME='worker-1'

hostname $HOSTNAME
echo $HOSTNAME > /etc/hostname

ln -s /etc/kubernetes/kubelet.conf /root/.kube/config

# PASTE JOIN HERE
kubeadm join 10.0.0.153:6443 --token jmug2q.qj9f2aj2hvra1xv2 --discovery-token-ca-cert-hash sha256:9c75364401696be952ebaa607f969c87df173b67b6ba8eb11ff8f6b77a5e6529 
