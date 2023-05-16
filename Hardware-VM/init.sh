#!/bin/bash

# When booting from the ISO image, all changes are lost!
# Set up network interface
cat <<EOT >> /etc/network/interfaces
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOT

/etc/init.d/networking restart

# Update APK library to the latest-stable version
echo http://dl-cdn.alpinelinux.org/alpine/latest-stable/main >> /etc/apk/repositories
echo http://dl-cdn.alpinelinux.org/alpine/latest-stable/community >> /etc/apk/repositories

apk update && apk upgrade

