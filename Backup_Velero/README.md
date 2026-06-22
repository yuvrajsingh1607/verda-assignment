# Backup: Velero

Namespace-Scoped Backups for Rancher, Argo CD, Harbor, and Cluster Resources — Reference

## 1. Overview & Relationship to etcd Snapshots

This document covers Velero, which is complementary to the raw etcd snapshot covered in the separate cluster-state backup document, not a replacement for it. The two protect against different failure modes:

Both were actually installed and tested in this cluster:  etcd snapshot (58 MB, hash-verified) and a fully working Velero install with a self-hosted MinIO backend, exercised with a real backup-then-restore cycle before being pointed at the actual workload namespaces.

## 2. Install
```bash
wget https://github.com/vmware-tanzu/velero/releases/download/v1.15.2/velero-v1.15.2-linux-amd64.tar.gz

tar -xvf velero-v1.15.2-linux-amd64.tar.gz

install -m 755 velero-v1.15.2-linux-amd64/velero /usr/local/bin/velero

kubectl create namespace velero
```
## 3. Backend: Self-Hosted MinIO

No external cloud object storage was available in this environment, so Velero's S3-compatible backend requirement was satisfied with a self-hosted MinIO instance inside the cluster. See minio-backend.yaml for the full Deployment/Service.

Known limitation, by design for this lab setup:  MinIO's data volume uses emptyDir, meaning backup data does not survive a pod restart or reschedule. Acceptable for this demonstration; for any real use, back the volume with a PVC at minimum, or point Velero at genuine external object storage instead of a self-hosted, single-replica MinIO.
```bash
kubectl apply -f minio-backend.yaml
kubectl exec -it -n velero minio-client -- sh
  mc alias set local http://minio:9000 minioadmin <password>
  mc mb local/k8s-backups
```
## 4. Connect Velero to the MinIO Backend

```bash
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.10.0 \
  --bucket k8s-backups \
  --backup-location-config region=minio,s3ForcePathStyle="true",s3Url=http://minio.velero.svc.cluster.local:9000 \
  --secret-file <(cat <<EOF
[default]
aws_access_key_id = minioadmin
aws_secret_access_key = <password>
EOF
  ) \
  --use-volume-snapshots=false \
  --namespace velero
```
Note:  The AWS plugin is used purely for its S3-API-compatible client — no AWS account or service is actually involved; --provider aws here just selects the plugin that knows how to speak the S3 protocol, which MinIO also implements.

```bash
root@master-1:~# velero backup-location get
NAME      PROVIDER   BUCKET/PREFIX   PHASE       LAST VALIDATED                  ACCESS MODE   DEFAULT
default   aws        k8s-backups     Available   2026-06-22 09:46:47 +0000 UTC   ReadWrite     true
```


## 5. Verification: a Real Backup-and-Restore Cycle

Before trusting this setup for anything real, a backup and restore were both actually exercised against a throwaway namespace, not just configured and assumed to work.

```bash
root@master-1:~# velero backup create test-backup-1 --include-namespaces velero
Backup request "test-backup-1" submitted successfully.
Run `velero backup describe test-backup-1` or `velero backup logs test-backup-1` for more details.

root@master-1:~# velero restore create test-restore-1 --from-backup test-backup-1
Restore request "test-restore-1" submitted successfully.
Run `velero restore describe test-restore-1` or `velero restore logs test-restore-1` for more details.
```



## 6. Backups: Per-Component

Once the backup-and-restore cycle was verified, real backups were taken of each actual workload area:
```bash
root@master-1:~# velero backup create rancher-backup-1 \
  --include-namespaces cattle-system,cattle-fleet-system,cattle-fleet-local-system,cattle-fleet-clusters-system,cattle-global-data,cattle-impersonation-system,cattle-local-user-passwords

root@master-1:~# velero backup create argocd-backup-1 \
  --include-namespaces argocd

root@master-1:~# velero backup create harbor-backup-1 \
  --include-namespaces harbor

root@master-1:~# velero backup create cluster-state-backup-1 \
  --include-cluster-resources=true
```
Rancher's actual namespace footprint:  Rancher's state spans 7 namespaces, not just cattle-system — Fleet (GitOps), global data, impersonation, and local user passwords each have their own namespace. A backup that only targets cattle-system misses real state.

## 7. Scheduled (Recurring) Backups
```bash
root@master-1:~# velero schedule create cluster-daily \
  --schedule="@every 24h" \
  --include-cluster-resources=true

root@master-1:~# velero schedule create rancher-daily \
  --schedule="@every 24h" \
  --include-namespaces cattle-system,cattle-fleet-system,cattle-fleet-local-system,cattle-fleet-clusters-system,cattle-global-data,cattle-impersonation-system,cattle-local-user-passwords

root@master-1:~# velero schedule create argocd-daily \
  --schedule="@every 6h" \
  --include-namespaces argocd

root@master-1:~# velero schedule create harbor-daily \
  --schedule="@every 24h" \
  --include-namespaces harbor
```
Argo CD's schedule is intentionally more frequent (6h vs. 24h) than the others — reflecting that Application/AppProject objects can change more often during active development than Rancher or Harbor's relatively stable configuration.

## 8. Restore Procedures, Per Component

velero restore create full-restore       --from-backup cluster-state-backup-1
velero restore create rancher-restore    --from-backup rancher-backup-1
velero restore create argocd-restore     --from-backup argocd-backup-1
velero restore create harbor-restore     --from-backup harbor-backup-1

Restoring Harbor specifically:  A Velero restore of Harbor's namespace restores the Kubernetes objects (Deployments, Services, the PVC objects themselves) but the actual PVC data (registry blobs, the Postgres database's files) is governed by --use-volume-snapshots=false in this setup — meaning PV contents are NOT captured by these backups at all. This mirrors the same point made in the Harbor reference document: registry blobs need either object-storage migration or a separate, explicit volume-backup mechanism (e.g. Velero with a real CSI snapshot driver, not the false setting used here for simplicity).

## 9. Retention
```bash
velero backup create cluster-daily --ttl 720h0m0s   # 30 days
```
## 10. The One Thing Velero Doesn't Cover: Plaintext Secrets

Velero backs up Secret objects as-is — base64-encoded, not separately encrypted, unless Velero's own backup encryption or the cluster's encryption-at-rest is separately configured (neither was set up here). A simple, very basic point-in-time capture used during this work, worth flagging as NOT a substitute for proper backup tooling:

## 10. backup all manifests config
```bash
kubectl get all -A -o yaml > backup.yaml
```
This file contains every Secret in the cluster in recoverable form and any real Velero backup stored in the MinIO bucket, as highly sensitive — encrypt at rest and restrict access tightly, exactly as called out in the etcd-snapshot backup document for the same underlying reason.
## 11. backup etcd individually
We should also take sperate backup of etcd component as it is one of the most important component on the cluster

```bash
root@master-1:~# apt-get install -y etcd-client

root@master-1:~# mkdir -p /var/backups/etcd

root@master-1:~# ETCDCTL_API=3 etcdctl snapshot save /var/backups/etcd/etcd-snapshot-$(date +%Y%m%d-%H%M%S).db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

  {"level":"info","ts":1782048148.0095654,"caller":"snapshot/v3_snapshot.go:119","msg":"created temporary db file","path":"/var/backups/etcd/etcd-snapshot-20260621-132228.db.part"}
{"level":"info","ts":"2026-06-21T13:22:28.012793Z","caller":"clientv3/maintenance.go:212","msg":"opened snapshot stream; downloading"}
{"level":"info","ts":1782048148.012819,"caller":"snapshot/v3_snapshot.go:127","msg":"fetching snapshot","endpoint":"https://127.0.0.1:2379"}
{"level":"info","ts":"2026-06-21T13:22:28.17416Z","caller":"clientv3/maintenance.go:220","msg":"completed snapshot read; closing"}
{"level":"info","ts":1782048148.2067099,"caller":"snapshot/v3_snapshot.go:142","msg":"fetched snapshot","endpoint":"https://127.0.0.1:2379","size":"58 MB","took":0.197048514}
{"level":"info","ts":1782048148.2068179,"caller":"snapshot/v3_snapshot.go:152","msg":"saved","path":"/var/backups/etcd/etcd-snapshot-20260621-132228.db"}
Snapshot saved at /var/backups/etcd/etcd-snapshot-20260621-132228.db

root@master-1:~# ETCDCTL_API=3 etcdctl snapshot status /var/backups/etcd/etcd-snapshot-20260621-132228.db --write-out=table
+----------+----------+------------+------------+
|   HASH   | REVISION | TOTAL KEYS | TOTAL SIZE |
+----------+----------+------------+------------+
| e7fa171b |   591791 |      11725 |      58 MB |
+----------+----------+------------+------------+
```