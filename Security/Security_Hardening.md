# Security Hardening

**An Honest Audit of This Cluster's Current Posture, and What to Fix Before Production**

## 1. How to Read This Document

This is not a generic Kubernetes hardening checklist. Every finding below
is a real, specific gap identified in *this* cluster, discovered as a
byproduct of the work done across the other reference documents — not a
hypothetical "best practice" pulled from a textbook. Each finding states
what's true today, why it matters, and the concrete fix.

Findings are grouped by how urgent they are, not by topic, since urgency
is what actually determines what to fix first.

---

## 2. Critical — Fix Before Any Real Use

### 2.1 Every cluster-internal firewall rule allows from "Anywhere"

`09-master-firewall.sh` and `10-worker-firewall.sh` open every
Kubernetes-internal port (`6443`, `2379-2380`, `10250`, `10257`, `10259`,
the NodePort range, Cilium's `4240`/`8472`/`7946`) to `0.0.0.0/0` — the
entire public internet, not just the cluster's own 6-7 node IPs.

> **Risk:** Every one of these ports is a public-facing attack surface.
> The API server, etcd, and kubelet are all directly reachable from
> anywhere on the internet today. The only thing standing between an
> attacker and these ports is whatever authentication each service
> itself enforces — there is no network-layer defense at all.

### 2.3 Cilium network policy is fully open by default

Confirmed directly: every pod endpoint in the cluster showed
`Ingress: Disabled` before today's one demonstration policy was applied.
Any pod can currently reach any other pod or Service, across every
namespace — Harbor's database, Argo CD's API, Rancher's internals, all
mutually reachable from anything, including a compromised low-value pod
in an unrelated namespace.

> **Risk:** A single compromised workload (even something as low-stakes
> as the `gpu-burn-test` or `kwok-demo` pods used for earlier
> demonstrations) currently has unrestricted network access to every
> other workload in the cluster, including Rancher, Argo CD, and
> Harbor's databases.


---

## 3. High Priority — Fix Soon

### 3.1 No `ResourceQuota` or `LimitRange` on any namespace

Nothing currently stops a single namespace (or a single misbehaving pod)
from consuming the entire cluster's CPU/memory. Kueue's `ClusterQueue`
(4 CPU / 8Gi) governs *batch Jobs* specifically, but ordinary
Deployments, the verda-flask environments, Rancher, Argo CD, and Harbor
all have no quota ceiling at all.


### 3.2 RBAC: a single numeric GitHub user ID is hardcoded as cluster-admin

`argocd-rbac-cm`'s `policy.csv` grants `role:admin` to one specific
numeric GitHub user ID. This is correct for a single-operator lab setup,
but is a real liability if this cluster outlives being a one-person
project — there is no team-based or group-based access model, and the
mapping from "numeric ID" back to "which human this actually is" lives
nowhere except this document and the original troubleshooting session.

**Fix for a real team:** use GitHub org/team membership via the
`groups` claim (Dex's `scopes: '[groups]'` setting already requests
this) rather than individual numeric IDs, once the GitHub account in
use actually belongs to an org with team structure.

### 3.3 Self-signed certificates everywhere, with no central tracking

Rancher, Argo CD, Harbor, and Grafana each have their own independently
bootstrapped self-signed CA (four separate CAs, four separate trust
roots). None of these are tracked in any inventory; renewal dates,
rotation procedures, and "what trusts what" exist only in the four
separate reference documents.

> **Risk:** When any of these CAs needs rotating (cert-manager's default
> CA certs are valid ~90 days per the `Not After` dates seen during
> today's work), there is no single place that tracks which systems
> need their trust store updated as a result.

**Fix:** For anything beyond a lab/demo, replace self-signed CAs with a
real CA (an internal one via `step-ca`/Vault PKI, or a public one via
Let's Encrypt if these hostnames become real DNS names instead of
`sslip.io` addresses) — and in the meantime, maintain a simple inventory
of every Issuer/Certificate pair and its expiry.

### 3.4 No pod security standards enforced

No `PodSecurityStandard` (the `restricted`, `baseline`, or `privileged`
admission labels Kubernetes provides natively) is set on any namespace.
Nothing currently prevents a pod from requesting `privileged: true`,
running as root, or mounting the host's filesystem.


## 4. Medium Priority — Worth Doing

### 4.1 No audit logging enabled

`kube-apiserver` is running with no `--audit-log-path` or audit policy
configured. There is currently no record of who did what, when — every
`kubectl exec`, every Secret read, every RBAC change made throughout
this entire engagement left no audit trail beyond whatever each
individual tool's own logs happened to capture.


### 4.2 Trivy is installed but its findings were never reviewed

Harbor's Trivy scanner is enabled and presumably scanned `verda-flask:v1`
on push, but no Trivy report was ever actually pulled and reviewed
during this engagement.

Treat any `Critical`/`High` findings as a real gate, not a dashboard
curiosity — this is exactly the kind of alert flagged as worth
configuring alerting section, but
it needs a human to actually look at it at least once before trusting
the alert to catch the next one.

### 4.3 etcd snapshot and Velero backups exist locally only

The 58 MB etcd snapshot lives at `/var/backups/etcd/` on `master-1`
itself. Velero's MinIO backend uses `emptyDir` storage. Neither backup
has actually left the cluster's own infrastructure.

> **Risk:** Any failure that takes down `master-1` or the cluster's
> storage simultaneously takes down the only copies of every backup —
> the exact scenario backups are supposed to protect against.

---

## 5. Lower Priority — Good Practice, Not Urgent Here

- **Harbor's image scanning policy** is not set to block pulls of
  vulnerable images — it scans and reports, but doesn't prevent
  deployment of an image with known critical CVEs. Worth enabling
  "prevent vulnerable images from running" once Trivy findings have
  actually been reviewed (Section 4.2) and a reasonable severity
  threshold is chosen.
- **No `NetworkPolicy`/`CiliumNetworkPolicy` egress restrictions to the
  public internet** exist for any workload except the one example
  written (not yet applied) in `Cilium_Reference.md`. Every pod can
  currently reach the public internet directly.
---

## 6. Summary Table

| Priority | Finding | Status |
|---|---|---|
| Critical | Firewall rules open to "Anywhere" | Needs scoping to node IPs |
| Critical | Network policy fully open by default | One policy deployed; rest pending |
| High | No ResourceQuota/LimitRange anywhere | Not yet applied |
| High | Single hardcoded numeric ID as cluster-admin | Acceptable for solo use; not team-ready |
| High | Four untracked self-signed CAs | No inventory; fine for lab, not for production |
| High | No Pod Security Standards enforced | Not yet applied |
| Medium | No audit logging | Not configured |
| Medium | Trivy findings never reviewed | Scanner running, output unreviewed |
| Medium | Backups stored locally only | Real external storage needed |
