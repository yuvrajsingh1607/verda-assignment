#!/bin/bash

set -e

echo "== Kubernetes Ports =="

# API server
sudo ufw allow 6443/tcp

# etcd
sudo ufw allow 2379:2380/tcp

# kubelet
sudo ufw allow 10250/tcp

# controller + scheduler
sudo ufw allow 10257/tcp
sudo ufw allow 10259/tcp

# node ports
sudo ufw allow 30000:32767/tcp

# DNS port

sudo ufw allow 53/udp
sudo ufw allow 53/tcp

echo "allow Cilium ports"
sudo ufw allow 4240/tcp
sudo ufw allow 8472/udp
sudo ufw allow 4240/udp
sudo ufw allow 7946/tcp
sudo ufw allow 7946/udp

sudo ufw reload
sudo ufw status