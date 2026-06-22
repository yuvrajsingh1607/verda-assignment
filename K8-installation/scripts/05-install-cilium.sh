#!/bin/bash

set -e

echo "== Install Cilium CLI =="
curl -L --remote-name https://github.com/cilium/cilium-cli/releases/latest/download/cilium-linux-amd64.tar.gz

tar xzvf cilium-linux-amd64.tar.gz
sudo mv cilium /usr/local/bin/
rm cilium-linux-amd64.tar.gz

echo "== Install Cilium CNI =="
cilium install

echo "== Verify Cilium =="
cilium status

echo "Cilium installed"