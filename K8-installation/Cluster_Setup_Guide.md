# Building the Kubernetes Cluster — Consolidated Steps

This consolidates the 10 setup scripts into a single, ordered build guide,
covering master and worker node installation and configuration with
kubeadm and Cilium. Real issues hit during the actual build are called
out inline, not just the "happy path" commands.

## Architecture

- **kubeadm**-based cluster (not a packaged distribution like RKE2/k3s)
- **Cilium** as the CNI, installed via the Cilium CLI
- Ubuntu 24.04 VMs with public IPs (no private/internal network — every
  node reaches every other node over its real public IP)
- 3 control-plane nodes + N worker nodes

## Script Order and Purpose

| # | Script | Runs on | Purpose |
|---|---|---|---|
| 1 | `01-prerequisites.sh` | Every node | OS hardening baseline, swap/kernel/sysctl prep |
| 2 | `02-containerd.sh` | Every node | Container runtime install + cgroup config |
| 3 | `03-kubernetes.sh` | Every node | kubeadm, kubelet, kubectl install |
| 4 | `04-init-master.sh` | First master only | Initialize the control plane |
| 5 | `05-install-cilium.sh` | First master only | Install the CNI |
| 6 | `06-join-worker.sh` | Each worker | Join a worker node |
| 7 | `07-join-master.sh` | Each additional master | Join an additional control-plane node |
| 8 | `08-verify.sh` | Any node with `kubectl` | Cluster health and connectivity check |
| 9 | `09-master-firewall.sh` | Every master | `ufw` rules for control-plane nodes |
| 10 | `10-worker-firewall.sh` | Every worker | `ufw` rules for worker nodes |

---

## 1. `01-prerequisites.sh` — every node

Installs `fail2ban` and `ufw`, disables swap (a hard kubeadm requirement),
loads the `overlay` and `br_netfilter` kernel modules, and sets the
sysctl flags Kubernetes networking depends on.

```bash
sudo apt update
sudo apt install -y fail2ban ufw
sudo systemctl enable --now fail2ban
sudo ufw allow ssh
sudo ufw enable

sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.ip_forward=1
EOF
sudo sysctl --system
```

**Verify:** `swapon --show` returns nothing; `lsmod | grep br_netfilter`
shows the module loaded.

## 2. `02-containerd.sh` — every node

Installs containerd and switches its cgroup driver to `systemd` —
required to match kubelet's own cgroup driver.

```bash
sudo apt install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd
```

**Verify:** `systemctl status containerd` shows `active (running)`.

## 3. `03-kubernetes.sh` — every node

Adds the official Kubernetes apt repo (pinned to v1.34) and installs
`kubelet`, `kubeadm`, `kubectl`, then holds their versions so a routine
`apt upgrade` can't silently change the cluster's Kubernetes version.

```bash
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /" | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

> **Note:** v1.34 is pinned explicitly. Tracking a newer minor later
> requires deliberately updating both the repo line and the
> `apt-mark hold` — it will not happen automatically, by design.

## 4. `04-init-master.sh` — first master only

Initializes the control plane and uploads certificates so additional
control-plane nodes can join later.

```bash
MASTER_IP="95.133.253.81"
POD_CIDR="10.244.0.0/16"

sudo kubeadm init \
  --apiserver-advertise-address=$MASTER_IP \
  --control-plane-endpoint=$MASTER_IP:6443 \
  --pod-network-cidr=$POD_CIDR \
  --upload-certs

mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubeadm token create --print-join-command > join-worker.sh
```

> **Note on pod CIDR:** `10.244.0.0/16` is set here, but Cilium (installed
> next) manages its own IPAM independently — the actual per-node pod CIDR
> Cilium assigns may differ from this flag's value. This is expected, not
> a misconfiguration.

## 5. `05-install-cilium.sh` — first master only

```bash
curl -L --remote-name https://github.com/cilium/cilium-cli/releases/latest/download/cilium-linux-amd64.tar.gz
tar xzvf cilium-linux-amd64.tar.gz
sudo mv cilium /usr/local/bin/
rm cilium-linux-amd64.tar.gz

cilium install
cilium status
```

**Verify:** `cilium status` shows `Cilium: OK` and `Operator: OK` once
nodes have joined. Until at least one worker joins, the DaemonSet will
show fewer ready pods than desired — expected at this stage.

## 6. `06-join-worker.sh` — each worker node

```bash
sudo kubeadm join $MASTER_IP:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash>
```

> Always regenerate the token first (see the callout under step 4) — do
> not reuse a previously saved join script.

## 7. `07-join-master.sh` — each additional control-plane node

Differs from a worker join in two ways: the `--control-plane` flag, and a
`--certificate-key`, which lets the new master pull the control-plane
certificates uploaded during `init`.

```bash
sudo kubeadm join $MASTER_IP:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash> \
  --control-plane --certificate-key <key>
```

> The `--certificate-key` has its **own, shorter TTL** (2 hours), separate
> from the bootstrap token's 24-hour TTL. If more than 2 hours have
> passed since `init`, re-upload the certs first:
> ```bash
> sudo kubeadm init phase upload-certs --upload-certs
> ```

**Verify after every join (worker or master):**
```bash
kubectl get nodes
```
New nodes start `NotReady` and flip to `Ready` once Cilium's agent pod on
that node finishes initializing.

## 8. `08-verify.sh` — any node with `kubectl` access

```bash
kubectl get nodes -o wide
kubectl get pods -A
kubectl cluster-info
cilium status
cilium connectivity test
```

`cilium connectivity test` deploys temporary test pods to exercise
pod-to-pod, pod-to-service, and cross-node connectivity end to end. It
creates a temporary `cilium-test` namespace and runs for several minutes
— safe to re-run any time.

## 9. `09-master-firewall.sh` — every control-plane node

```bash
sudo ufw allow 6443/tcp        # API server
sudo ufw allow 2379:2380/tcp   # etcd
sudo ufw allow 10250/tcp       # kubelet
sudo ufw allow 10257/tcp       # controller-manager health
sudo ufw allow 10259/tcp       # scheduler health
sudo ufw allow 30000:32767/tcp # NodePort range
sudo ufw allow 53/udp
sudo ufw allow 53/tcp          # DNS
sudo ufw allow 4240/tcp        # Cilium health checks
sudo ufw allow 8472/udp        # Cilium VXLAN overlay
sudo ufw allow 4240/udp
sudo ufw allow 7946/tcp        # Cilium gossip
sudo ufw allow 7946/udp
sudo ufw reload
```

## 10. `10-worker-firewall.sh` — every worker node

A subset of the master rules — kubelet, NodePort range, Cilium ports, and
DNS. Workers don't run the API server or etcd, so `6443`/`2379-2380` are
correctly omitted.

```bash
sudo ufw allow 10250/tcp
sudo ufw allow 30000:32767/tcp
sudo ufw allow 8472/udp
sudo ufw allow 4240/tcp
sudo ufw allow 7946/tcp
sudo ufw allow 7946/udp
sudo ufw allow 53/udp
sudo ufw allow 53/tcp
sudo ufw reload
```
---

## Summary: What to Run, in Order

1. **01, 02, 03** on every node (masters and workers alike) — pure OS/runtime prep, identical regardless of role.
2. **04** once, on the first master, to initialize the control plane.
3. **05** once, on the first master, to install Cilium.
4. **09** on every master, **10** on every worker — firewall rules, ideally *before* joining so the node is reachable on the right ports from the moment it joins.
5. **07** on each additional master; **06** on each worker — always with a freshly generated token, never a saved one.
6. **08** at any point to verify cluster health, and again after any significant change.

## Known Gaps Worth Closing

| Gap | Impact | Fix |
|---|---|---|
| Firewall rules allow from "Anywhere" | Every cluster-internal port is reachable from the public internet | Scope rules to specific peer node IPs |
