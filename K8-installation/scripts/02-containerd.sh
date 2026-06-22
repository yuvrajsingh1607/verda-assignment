#!/bin/bash

set -e

echo "== Install containerd =="
sudo apt update
sudo apt install -y containerd

echo "== Create default config =="
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

echo "== Enable systemd cgroup driver =="
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

echo "== Restart containerd =="
sudo systemctl restart containerd
sudo systemctl enable containerd

echo "containerd setup completed"