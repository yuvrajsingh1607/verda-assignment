#!/bin/bash

set -e

echo "== Cluster Nodes =="
kubectl get nodes -o wide

echo "== All Pods =="
kubectl get pods -A

echo "== Cluster Info =="
kubectl cluster-info

echo "== Cilium Status =="
cilium status

echo "== Connectivity Test =="
cilium connectivity test