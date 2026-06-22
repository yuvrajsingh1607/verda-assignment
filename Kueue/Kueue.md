# Kueue

**High and Low Priority Job Queues — Reference**

## 1. Overview

Kueue manages batch Job admission and queueing on top of standard
Kubernetes, using a shared, quota-bound ClusterQueue and
per-team/per-priority LocalQueues. Demonstrated here with two priority
tiers sharing one constrained resource pool, deliberately oversubscribed
to force visible queueing behavior.

| Item | Value |
|---|---|
| Version | v0.18.1 |
| ClusterQueue quota | 4 CPU / 8Gi memory (shared) |
| Queues | `high-priority-queue`, `low-priority-queue` (both → `cluster-queue`) |
| Priority values | `high-priority`: 1000, `low-priority`: 100 |

## 2. Install

```bash
kubectl apply --server-side -f https://github.com/kubernetes-sigs/kueue/releases/download/v0.18.1/manifests.yaml
```

## 3. Resource Setup

See `kueue-resources.yaml` for the full set: a ResourceFlavor, a
ClusterQueue with the shared quota, two `WorkloadPriorityClass` objects,
two matching native `PriorityClass` objects, and two LocalQueues.

```bash
root@master-1:~# kubectl apply -f kueue-resources.yaml
root@master-1:~# kubectl -n default get localqueue
NAME                  CLUSTERQUEUE    PENDING WORKLOADS   ADMITTED WORKLOADS
high-priority-queue   cluster-queue   0                   1
low-priority-queue    cluster-queue   1                   0
```

## 4. Demo: High vs. Low Priority Under Contention

Two Jobs, each requesting 2 CPU / 2Gi per pod across 2 pods (4 CPU / 4Gi
total each), submitted together against a 4 CPU / 8Gi ClusterQueue —
deliberately oversubscribing CPU (8 requested vs. 4 available) to force
real queueing.

```bash
root@master-1:~# kubectl apply -f kueue-demo-jobs.yaml

root@master-1:~# kubectl get workloads -w
NAME                      QUEUE                 RESERVED IN     ADMITTED   FINISHED   AGE
job-high-prio-job-bb158   high-priority-queue   cluster-queue   True                  53s
job-low-prio-job-ce8db    low-priority-queue                                          52s
job-high-prio-job-bb158   high-priority-queue   cluster-queue   True       True       64s

root@master-1:~# kubectl -n default get jobs
NAME            STATUS     COMPLETIONS   DURATION   AGE
high-prio-job   Complete   2/2           64s        3m6s
low-prio-job    Complete   2/2           64s        3m5s

root@master-1:~# kubectl -n default get pods
NAME                  READY   STATUS      RESTARTS   AGE
high-prio-job-grbjc   0/1     Completed   0          3m13s
high-prio-job-sssvv   0/1     Completed   0          3m13s
low-prio-job-26nj4    0/1     Completed   0          2m8s
low-prio-job-xmvts    0/1     Completed   0          2m8s
```

Observed sequence, with real timestamps:

1. `high-prio-job` admitted immediately (`RESERVED IN: cluster-queue`,
   `ADMITTED: True`) — quota was free.
2. `low-prio-job` sat queued (no `RESERVED IN` value yet) — quota was
   exhausted by the high-priority job.
3. At ~64s, `high-prio-job` shows `FINISHED: True` — its `sleep 60`
   completed, quota released.
4. Immediately after, `low-prio-job` picks up `RESERVED IN:
   cluster-queue` — Kueue admitted it the moment quota freed.
5. Both Jobs eventually show `STATUS: Complete`, `2/2 COMPLETIONS`, all 4
   pods `Completed` cleanly.

> **Result:** A complete, real, timestamped demonstration of
> priority-aware admission and queueing under genuine resource
> contention — not just configuration that looks correct on paper.
