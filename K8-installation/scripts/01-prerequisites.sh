#!/bin/bash

set -e
sudo apt update
sudo apt install -y fail2ban
sudo systemctl start fail2ban
sudo systemctl enable fail2ban
sudo apt install -y ufw
sudo ufw allow ssh
sudo ufw enable
sudo ufw status
sudo fail2ban-client status
sudo fail2ban-client status sshd

echo "== Disable Swap =="
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

echo "== Load kernel modules =="
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

echo "== Sysctl settings for Kubernetes =="
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.ip_forward=1
EOF

sudo sysctl --system

echo "== Install base tools =="
sudo apt update
sudo apt install -y curl apt-transport-https ca-certificates gpg

echo "== UFW rules =="
sudo ufw allow OpenSSH
sudo ufw --force enable

echo "Prerequisites completed"