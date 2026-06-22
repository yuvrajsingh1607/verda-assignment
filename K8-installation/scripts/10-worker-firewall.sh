#!/bin/bash

set -e

sudo ufw allow 10250/tcp
sudo ufw allow 30000:32767/tcp

# Cilium networking
sudo ufw allow 8472/udp
sudo ufw allow 4240/tcp
sudo ufw allow 7946/tcp
sudo ufw allow 7946/udp

# Kubernetes DNS
sudo ufw allow 53/udp
sudo ufw allow 53/tcp

sudo ufw reload
sudo ufw status

# iptables -t nat -A OUTPUT -d 10.96.0.1 -p tcp --dport 443 -j DNAT --to-destination 95.133.253.81:6443
# iptables -t nat -D OUTPUT -d 10.96.0.1 -p tcp --dport 443 -j DNAT --to-destination 95.133.253.81:6443

