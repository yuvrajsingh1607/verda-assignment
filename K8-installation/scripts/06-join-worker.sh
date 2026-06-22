#!/bin/bash
# kubeadm token list
# TTL for token is 24 hours so create a new token
# kubeadm token create --print-join-command

set -e

echo "Joining worker node to cluster"

 sudo kubeadm join 95.133.253.81:6443 --token b2022i.x3wqkr8z42yw0gfk --discovery-token-ca-cert-hash sha256:4e60e97aa35dc522af644d53017eb4a6d0faecfd4515ad35f71e5b6341be8d3f