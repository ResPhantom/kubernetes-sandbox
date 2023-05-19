#!/bin/sh

# Update APK library to the latest-stable version
cat <<'EOT' >> /etc/apk/repositories
http://dl-cdn.alpinelinux.org/alpine/latest-stable/main
http://dl-cdn.alpinelinux.org/alpine/latest-stable/community
http://dl-cdn.alpinelinux.org/alpine/edge/community
http://dl-cdn.alpinelinux.org/alpine/edge/testing
EOT

apk update && apk upgrade
apk update --available
apk upgrade --available

# Install util packages
apk add cni-plugin-flannel \
        cni-plugins \
        flannel \
        flannel-contrib-cni \
        uuidgen \
        nfs-utils

# Install Kubernetes packages
apk add kubelet \
        kubeadm \
        kubectl \
        containerd

# Add kernel module for networking
echo "br_netfilter" > /etc/modules-load.d/k8s.conf
modprobe br_netfilter
echo 1 > /proc/sys/net/ipv4/ip_forward

# Remove swap storage
cat /etc/fstab | grep -v swap > temp.fstab
cat temp.fstab > /etc/fstab
rm temp.fstab
swapoff -a

# Fix id error messages
uuidgen > /etc/machine-id

# Add services
rc-update add containerd
rc-update add kubelet
rc-update add ntpd

# Start services
/etc/init.d/ntpd start
/etc/init.d/containerd start

# Create flannel Symlink
ln -s /usr/libexec/cni/flannel-amd64 /usr/libexec/cni/flannel

# Ensure that brigeded packets traverse iptable rules
echo "net.bridge.bridge-nf-call-iptables=1" >> /etc/sysctl.conf
sysctl net.bridge.bridge-nf-call-iptables=1

# Pin your versions!  If you update and the nodes get out of sync, it implodes.
apk add 'kubelet=~1.26'
apk add 'kubeadm=~1.26'
apk add 'kubectl=~1.26'

# Note that in the future you will manually have to add a newer version the same way to upgrade.