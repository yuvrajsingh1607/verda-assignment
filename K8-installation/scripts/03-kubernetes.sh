#!/bin/bash

set -e

echo "== Add Kubernetes repo =="
sudo mkdir -p /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | \
sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /" | \
sudo tee /etc/apt/sources.list.d/kubernetes.list

echo "== Install kubeadm, kubelet, kubectl =="
sudo apt update
sudo apt install -y kubelet kubeadm kubectl

sudo apt-mark hold kubelet kubeadm kubectl

echo "Kubernetes packages installed"