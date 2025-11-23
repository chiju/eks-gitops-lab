# Monitoring Persistence Setup

## Overview

This lab demonstrates **production-grade monitoring persistence** using StatefulSets and persistent volumes.

## Architecture

```
┌─────────────────────────────────────────┐
│   Prometheus (StatefulSet)             │
│   ├─ 50Gi PVC (gp3)                    │
│   ├─ 15 days retention                 │
│   ├─ 45GB size limit                   │
│   └─ Survives pod restarts             │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│   AlertManager (StatefulSet)           │
│   ├─ 10Gi PVC (gp3)                    │
│   └─ Alert state persistence           │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│   Grafana (Deployment)                 │
│   ├─ 10Gi PVC (gp3)                    │
│   └─ Dashboard persistence             │
└─────────────────────────────────────────┘
```

## What Gets Persisted

### Prometheus (StatefulSet)
- **TSDB blocks** - Time-series data in 2-hour blocks
- **WAL** - Write-Ahead Log for crash recovery
- **Retention:** 15 days or 45GB (whichever hits first)
- **Storage:** 50Gi gp3 EBS volume

### AlertManager (StatefulSet)
- **Alert state** - Active alerts and silences
- **Notification history** - Sent alerts tracking
- **Storage:** 10Gi gp3 EBS volume

### Grafana (Deployment with PVC)
- **Dashboards** - Custom dashboard definitions
- **Data sources** - Connection configurations
- **User preferences** - Settings and favorites
- **Storage:** 10Gi gp3 EBS volume

## Configuration

### Prometheus Storage
```yaml
prometheus:
  prometheusSpec:
    retention: 15d          # Time-based retention
    retentionSize: 45GB     # Size-based retention
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: gp3
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 50Gi
```

### AlertManager Storage
```yaml
alertmanager:
  alertmanagerSpec:
    storage:
      volumeClaimTemplate:
        spec:
          storageClassName: gp3
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 10Gi
```

### Grafana Storage
```yaml
grafana:
  persistence:
    enabled: true
    storageClassName: gp3
    accessModes: ["ReadWriteOnce"]
    size: 10Gi
```

## Data Rotation

### Prometheus Automatic Rotation
```
Every hour, Prometheus checks:
├─ Is block older than 15 days? → DELETE
├─ Is total size > 45GB? → DELETE oldest blocks
└─ Keep deleting until under limits
```

**No manual intervention needed!**

## Testing Persistence

### 1. Deploy Monitoring Stack
```bash
# Push changes to trigger deployment
git add apps/kube-prometheus-stack/values.yaml
git commit -m "Add monitoring persistence"
git push

# Wait for ArgoCD to sync (3 minutes)
```

### 2. Verify PVCs Created
```bash
# Check Prometheus PVC
kubectl get pvc -n monitoring | grep prometheus

# Expected output:
# prometheus-monitoring-kube-prometheus-prometheus-0   Bound    pvc-xxx   50Gi       RWO            gp3            1m

# Check AlertManager PVC
kubectl get pvc -n monitoring | grep alertmanager

# Check Grafana PVC
kubectl get pvc -n monitoring | grep grafana
```

### 3. Verify StatefulSets
```bash
# Prometheus StatefulSet
kubectl get statefulset -n monitoring

# Expected:
# NAME                                    READY   AGE
# prometheus-monitoring-kube-prometheus   1/1     5m
# alertmanager-monitoring-kube-prometheus 1/1     5m
```

### 4. Test Data Persistence
```bash
# 1. Generate some metrics (wait 5 minutes)
kubectl run test-pod --image=nginx -n default

# 2. Query Prometheus
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090

# Open browser: http://localhost:9090
# Query: up{job="kubernetes-nodes"}

# 3. Delete Prometheus pod
kubectl delete pod prometheus-monitoring-kube-prometheus-prometheus-0 -n monitoring

# 4. Wait for pod to restart (30 seconds)
kubectl get pods -n monitoring -w

# 5. Query again - data should still be there!
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
# Same query should return historical data
```

### 5. Check Storage Usage
```bash
# Exec into Prometheus pod
kubectl exec -it prometheus-monitoring-kube-prometheus-prometheus-0 -n monitoring -- sh

# Check TSDB size
du -sh /prometheus

# List blocks
ls -lh /prometheus

# Expected output:
# drwxr-xr-x 3 1000 2000 4.0K Nov 23 10:00 01HXXX/  # Block 1
# drwxr-xr-x 3 1000 2000 4.0K Nov 23 12:00 01HYYY/  # Block 2
# drwxr-xr-x 2 1000 2000 4.0K Nov 23 14:00 wal/     # Write-Ahead Log
```

## Monitoring Metrics

### Prometheus Self-Monitoring
```promql
# Current storage size
prometheus_tsdb_storage_blocks_bytes

# Number of blocks
prometheus_tsdb_blocks_loaded

# Oldest block timestamp
prometheus_tsdb_lowest_timestamp

# Check if rotation is working
rate(prometheus_tsdb_blocks_deleted_total[1h])
```

### Grafana Dashboard
Import dashboard ID: **13639** (Prometheus 2.0 Stats)

Shows:
- Storage usage over time
- Block creation/deletion
- WAL size
- Compaction stats

## Troubleshooting

### Problem: PVC Not Created
```bash
# Check StorageClass exists
kubectl get storageclass gp3

# If not, check EBS CSI driver
kubectl get pods -n kube-system | grep ebs-csi
```

### Problem: Pod Stuck in Pending
```bash
# Check PVC status
kubectl describe pvc prometheus-monitoring-kube-prometheus-prometheus-0 -n monitoring

# Check events
kubectl get events -n monitoring --sort-by=.metadata.creationTimestamp
```

### Problem: Disk Full
```bash
# Check current usage
kubectl exec -it prometheus-monitoring-kube-prometheus-prometheus-0 -n monitoring -- df -h /prometheus

# If full, reduce retention
# Edit values.yaml:
retention: 7d        # Was 15d
retentionSize: 20GB  # Was 45GB
```

### Problem: Data Not Persisting
```bash
# Check if PVC is bound
kubectl get pvc -n monitoring

# Check pod is using PVC
kubectl describe pod prometheus-monitoring-kube-prometheus-prometheus-0 -n monitoring | grep -A 5 Volumes

# Should show:
#   prometheus-monitoring-kube-prometheus-prometheus-db:
#     Type:       PersistentVolumeClaim
#     ClaimName:  prometheus-monitoring-kube-prometheus-prometheus-0
```

## Cost Estimation

### Storage Costs (AWS eu-central-1)
```
Prometheus: 50Gi gp3 = $4.00/month
AlertManager: 10Gi gp3 = $0.80/month
Grafana: 10Gi gp3 = $0.80/month
────────────────────────────────────
Total: $5.60/month
```

### Optimization Tips
1. **Reduce retention** - 7 days instead of 15 days (saves 50%)
2. **Use gp2** - Slightly cheaper but slower
3. **Increase scrape interval** - 60s instead of 15s (saves 75% storage)
4. **Use recording rules** - Pre-aggregate expensive queries

## Production Considerations

### For Small Companies
```yaml
prometheus:
  retention: 7d
  retentionSize: 20GB
  storage: 30Gi
# Cost: ~$2.40/month
```

### For Medium Companies
```yaml
prometheus:
  retention: 15d
  retentionSize: 45GB
  storage: 50Gi
  replicas: 2  # HA
# Cost: ~$8/month (2 replicas)
```

### For Large Companies
```yaml
prometheus:
  retention: 30d
  retentionSize: 90GB
  storage: 100Gi
  replicas: 3  # HA
# Add Thanos for long-term storage
# Cost: ~$24/month + S3 costs
```

## Interview Talking Points

### Why StatefulSet?
> "Prometheus uses a StatefulSet because each instance needs:
> - Stable network identity for scraping
> - Dedicated persistent volume for TSDB
> - Ordered startup/shutdown for HA setups
> - Persistent storage that survives pod restarts"

### How does rotation work?
> "Prometheus automatically manages data rotation:
> - Creates 2-hour blocks from WAL
> - Checks retention limits every hour
> - Deletes blocks older than retention time
> - Deletes oldest blocks when size limit exceeded
> - No manual intervention needed"

### Why persistent storage?
> "Without persistence:
> - All metrics lost on pod restart
> - No historical data for troubleshooting
> - Can't track trends over time
> - Violates production requirements
>
> With persistence:
> - Data survives pod restarts
> - Historical analysis possible
> - Meets compliance requirements
> - Production-ready monitoring"

## Next Steps

1. **Add Thanos** - Long-term storage (months/years)
2. **Add Federation** - Multi-cluster monitoring
3. **Add Remote Write** - VictoriaMetrics for better compression
4. **Add Backup** - Velero for disaster recovery

---

**This setup demonstrates production-grade monitoring persistence patterns used in enterprise environments.** 🎯
