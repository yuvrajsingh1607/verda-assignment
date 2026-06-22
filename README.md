# Kubernetes Cluster — Reference Documentation

A 7-node kubeadm cluster (3 control-plane, 3 workers, 1 GPU worker) on
Verda Cloud, with Cilium as the CNI and every externally exposed service
behind a Cilium Gateway. This repo documents how each component was
installed, configured, demonstrated
working end-to-end.

## Folder Index

| Folder | Covers |
|---|---|
| [`Summary/`](./summary) | A short summary report: What was built. Architecture diagram and explanation. What worked and what did not. Security and operational considerations.  What could be improved with more time|
| [`K8-installation/`](./K8-installation) | The 10-script kubeadm + Cilium cluster build: prerequisites, containerd, kubeadm/kubelet/kubectl, control-plane init, Cilium install, node joins, verification, and firewall rules |
| [`Rancher/`](./Rancher) | Rancher Manager: Helm install, GitHub OAuth SSO, Cilium Gateway exposure|
| [`ArgoCD/`](./ArgoCD) | Argo CD: install, GitHub OAuth via Dex (including the RBAC numeric-subject gotcha), and the GitOps dev/staging/prod promotion structure |
| [`Harbor/`](./Harbor) | Harbor registry: install, the StorageClass prerequisite, and the three-layer CA-trust saga for pushing/pulling images through a self-signed registry |
| [`monitoring/`](./monitoring) | Prometheus + Grafana (kube-prometheus-stack): install, GPU/DCGM integration, and the production alerting strategy |
| [`cilium/`](./cilium) | Cilium network policy approach (with one policy deployed and verified end-to-end) and the Hubble Relay observability debugging chain |
| [`Kwok/`](./Kwok) | KWOK: simulating 94 additional fake nodes (100 total) and proving the real scheduler places workloads across them correctly |
| [`Kueue/`](./Kueue) | Kueue: high/low priority job queues sharing a constrained ClusterQueue, with a real, timestamped admission-and-preemption demo |
| [`Nvidia_workload_scheduling/`](./Nvidia_workload_scheduling) | NVIDIA GPU Operator on a real A100 node: driver/toolkit install, a genuine CUDA stress-test workload, and proof of scheduler placement |
| [`Backup_Velero/`](./Backup_Velero) | Backup strategy: a verified etcd snapshot plus a fully working Velero install (self-hosted MinIO backend) with a real backup-and-restore cycle, scheduled per-component |
| [`Security/`](./Security) | An honest security audit of this specific cluster's current posture — open firewall rules, missing quotas/policies — prioritized by urgency, not a generic checklist |

## How to Use This

Each folder is self-contained: a `.md` reference document plus the exact
`.yaml` manifests (and any helper scripts) it references by name. Start
with the `.md` file in any folder — it explains the installation commands and how the service is exposed or used.

Cluster was build using `K8-installation/`
first, then the others in the following order were built:
Rancher → ArgoCD → Harbor → monitoring → cilium → Kwok → Kueue →
Nvidia_workload_scheduling → Backup_Velero. `Security` is meant to be
read last, since it references findings from every other folder.

