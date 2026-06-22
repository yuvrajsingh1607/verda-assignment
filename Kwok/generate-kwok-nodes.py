#!/usr/bin/env python3
"""
Generates YAML manifests for N fake KWOK nodes, to be applied with kubectl.
Each node:
- Has the kwok.x-k8s.io/node=fake label (required for KWOK controller to manage it)
- Has a NoSchedule taint by default so real workloads don't accidentally land on
  fake nodes (KWOK nodes can't actually run real containers)
- Has realistic-looking capacity (CPU/memory/pods) so cluster-scale dashboards
  and `kubectl top nodes`-style views look like a genuine large cluster
"""
import sys

NUM_NODES = int(sys.argv[1]) if len(sys.argv) > 1 else 94
OUTPUT_FILE = sys.argv[2] if len(sys.argv) > 2 else "kwok-nodes.yaml"

NODE_TEMPLATE = """---
apiVersion: v1
kind: Node
metadata:
  annotations:
    node.alpha.kubernetes.io/ttl: "0"
    kwok.x-k8s.io/node: fake
  labels:
    beta.kubernetes.io/arch: amd64
    beta.kubernetes.io/os: linux
    kubernetes.io/arch: amd64
    kubernetes.io/hostname: {name}
    kubernetes.io/os: linux
    kwok.x-k8s.io/node: fake
    node-role.kubernetes.io/agent: ""
    type: kwok
  name: {name}
spec:
  taints:
    - effect: NoSchedule
      key: kwok.x-k8s.io/node
      value: fake
status:
  allocatable:
    cpu: "4"
    memory: 8Gi
    pods: "110"
  capacity:
    cpu: "4"
    memory: 8Gi
    pods: "110"
  nodeInfo:
    architecture: amd64
    bootID: ""
    containerRuntimeVersion: ""
    kernelVersion: ""
    kubeProxyVersion: fake
    kubeletVersion: fake
    machineID: ""
    operatingSystem: linux
    osImage: ""
    systemUUID: ""
  phase: Running
"""

with open(OUTPUT_FILE, "w") as f:
    for i in range(1, NUM_NODES + 1):
        f.write(NODE_TEMPLATE.format(name=f"kwok-node-{i:03d}"))

print(f"Generated {NUM_NODES} fake node manifests -> {OUTPUT_FILE}")
