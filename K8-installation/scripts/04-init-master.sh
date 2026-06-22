#!/bin/bash

set -e

MASTER_IP="95.133.253.81"
POD_CIDR="10.244.0.0/16"

echo "== Initializing Kubernetes control plane =="

sudo kubeadm init \
  --apiserver-advertise-address=$MASTER_IP \
  --control-plane-endpoint=$MASTER_IP:6443 \
  --pod-network-cidr=$POD_CIDR \
  --upload-certs

echo "== Setup kubeconfig =="
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "== Save join commands =="
kubeadm token create --print-join-command > join-worker.sh

echo "Master initialized"
echo "Worker join command saved in join-worker.sh"
