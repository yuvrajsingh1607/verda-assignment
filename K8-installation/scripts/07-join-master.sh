#!/bin/bash

set -e

echo "Joining control plane node"

sudo kubeadm join 95.133.253.81:6443 --token ulss5t.69o31p6aw6sol49g \
    --discovery-token-ca-cert-hash sha256:4e60e97aa35dc522af644d53017eb4a6d0faecfd4515ad35f71e5b6341be8d3f \
    --control-plane --certificate-key 5040b6d312d3e8b1411df6458f09764e265833453d4ca46f4edbf636f94c7694