# KWOK

**Simulating a 100-Node Cluster — Reference**

## 1. Overview

KWOK ("Kubernetes WithOut Kubelet") simulates fake nodes and lets the
real Kubernetes scheduler make genuine scheduling decisions against
them, without provisioning any real infrastructure. Used here to scale
this 6-real-node cluster up to 100 total nodes for demonstration
purposes.

| Item | Value |
|---|---|
| Real nodes | 6 (3 masters, 3 workers) |
| Simulated nodes added | 94 |
| Total nodes after simulation | 100 |
| Fake-node taint | `kwok.x-k8s.io/node=fake:NoSchedule` (keeps real workloads off the fake fleet) |

## 2. Install

```bash
KWOK_REPO=kubernetes-sigs/kwok
KWOK_LATEST_RELEASE=$(curl -s "https://api.github.com/repos/${KWOK_REPO}/releases/latest" | grep '"tag_name"' | cut -d'"' -f4)

kubectl apply -f "https://github.com/${KWOK_REPO}/releases/download/${KWOK_LATEST_RELEASE}/kwok.yaml"
kubectl apply -f "https://github.com/${KWOK_REPO}/releases/download/${KWOK_LATEST_RELEASE}/stage-fast.yaml"
```

> **Verify:** `kubectl -n kube-system get pods -l app=kwok-controller`
> should show `1/1 Running` within seconds.

## 3. Generating the Fake Node Fleet

`generate-kwok-nodes.py` (included alongside this document) generates N
distinct fake Node manifests, each with a unique name, the
`kwok.x-k8s.io/node=fake` label and taint, and realistic-looking
capacity (4 CPU / 8Gi / 110 pods) so cluster-scale views show plausible
numbers rather than obviously-fake zeros.

```bash
root@master-1:~# python3 generate-kwok-nodes.py 94 kwok-nodes.yaml
root@master-1:~# kubectl apply -f kwok-nodes.yaml
root@master-1:~# kubectl get nodes | grep kwok | wc -l
get nodes 94
root@master-1:~# kubectl get nodes
NAME            STATUS   ROLES           AGE   VERSION
kwok-node-001   Ready    agent           19s   fake
kwok-node-002   Ready    agent           19s   fake
kwok-node-003   Ready    agent           19s   fake
kwok-node-004   Ready    agent           19s   fake
...
```

> **Result:** 94 nodes added, each `Ready` within ~19 seconds, version
> reported as "fake" (correctly self-identifying, not masquerading as a
> real kubelet version). Combined with the 6 real nodes:
> `kubectl get nodes --no-headers | wc -l` returned exactly **100**.

## 4. Demonstrating Real Scheduling Against the Simulated Fleet

A 50-replica Deployment was scheduled with a matching toleration and
`nodeSelector`, forcing it specifically onto the fake fleet, to prove the
actual `kube-scheduler` (not a mock) is making real placement decisions
against the simulated nodes.

```bash
root@master-1:~# kubectl apply -f kwok-demo-deployment.yaml

root@master-1:~# kubectl get deployment kwok-demo
NAME        READY   UP-TO-DATE   AVAILABLE   AGE
kwok-demo   50/50   50           50          42s

root@master-1:~# kubectl get deployment kwok-demo
# READY 50/50, AVAILABLE 50

root@master-1:~# kubectl get pods -l app=kwok-demo -o wide --no-headers | awk '{print $7}' | sort | uniq -c | sort -rn | head -10
      1 kwok-node-092
      1 kwok-node-091
      1 kwok-node-090
      1 kwok-node-089
      1 kwok-node-087
      1 kwok-node-084
      1 kwok-node-082
      1 kwok-node-081
      1 kwok-node-080
      1 kwok-node-079
# one pod per fake node — confirms genuine spread-scheduling behavior,
# not a hardcoded or trivial placement
```

## 5. Cleanup

The fake fleet and demo Deployment persist until explicitly removed —
they do not expire or self-clean.

```bash
kubectl delete -f kwok-nodes.yaml
kubectl delete deployment kwok-demo
```
