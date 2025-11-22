# Rook Ceph Storage Integration

Distributed storage cluster using Rook Ceph operator, deployed via GitOps in the EKS cluster.

## 🚀 Deployment

```bash
export AWS_PROFILE=oth_infra

# Applications will auto-deploy via ArgoCD
# Monitor deployment status
kubectl -n argocd get applications | grep -E "(rook|ceph)"
```

## 📊 Components Deployed

### Rook Operator (`apps/rook-operator/`)
- **Chart**: `rook-ceph` v1.18.7 from `https://charts.rook.io/release`
- **Namespace**: `rook-ceph`
- **Features**: Discovery daemon, RBD/CephFS CSI drivers

### Ceph Cluster (`apps/ceph-cluster/`)
- **MON**: 3 monitors for consensus
- **MGR**: 2 managers with dashboard
- **OSD**: 3 OSDs using EBS volumes (`/dev/xvdb`)
- **Replication**: 3x for high availability

### Storage Classes (`apps/ceph-storage-classes/`)
- **RBD Block Storage**: `rook-ceph-block` storage class
- **Test App**: Sample deployment with PVC
- **Features**: Dynamic provisioning, volume expansion

## 🎯 Learning Areas

### Ceph Architecture
- **MON (Monitors)**: Cluster state and consensus (quorum-based)
- **OSD (Object Storage Daemons)**: Data storage and replication
- **MGR (Managers)**: Cluster management and metrics collection
- **CRUSH Map**: Data placement algorithm for fault tolerance

### Rook Operator Benefits
- **CRDs**: Kubernetes-native Ceph management
- **Lifecycle**: Automated deployment, scaling, upgrades
- **CSI Integration**: Dynamic volume provisioning
- **Self-healing**: Automatic recovery from failures

### Storage Operations
- **Block Storage (RBD)**: High-performance volumes for pods
- **Replication**: 3x data copies across failure domains
- **Failure Domains**: Host-level fault tolerance
- **CRUSH Rules**: Configurable data placement policies

## 🏗️ Current Setup vs Production

### Learning Setup (Current)
```yaml
# Mixed-use nodes (compute + storage)
storage:
  useAllNodes: true
  deviceFilter: "^xvdb"  # Single 100GB EBS volume
  
# Shared node resources
tolerations: []  # No dedicated storage nodes
```

### Production Best Practices
```yaml
# Dedicated storage nodes
nodeSelector:
  node-role: storage
tolerations:
- key: storage-node
  effect: NoSchedule

# Multiple devices per node
storage:
  nodes:
  - name: "storage-node-1"
    devices:
    - name: "/dev/nvme1n1"  # 1TB+ NVMe
    - name: "/dev/nvme2n1"  # Multiple devices
```

## 🔧 Monitoring Commands

```bash
# Check ArgoCD sync status
kubectl -n argocd get app rook-operator ceph-cluster ceph-storage-classes

# Monitor Rook pods
kubectl -n rook-ceph get pods -w

# Check Ceph cluster health
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph status

# View Ceph dashboard (port-forward)
kubectl -n rook-ceph port-forward svc/rook-ceph-mgr-dashboard 8443:8443

# Check storage classes
kubectl get storageclass | grep ceph

# Monitor test PVC
kubectl get pvc ceph-test-pvc
kubectl describe pvc ceph-test-pvc

# Check OSD utilization
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph df
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph osd df
```

## 🚨 Troubleshooting

```bash
# Check operator logs
kubectl -n rook-ceph logs -l app=rook-ceph-operator

# Check OSD status and placement
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph osd tree
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph pg stat

# Check cluster events
kubectl -n rook-ceph get events --sort-by='.lastTimestamp'

# Verify storage devices on nodes
kubectl get nodes -o wide
kubectl debug node/<node-name> -it --image=busybox -- lsblk
```

## 📚 Production Considerations

### Scaling
- **Node Groups**: Separate storage node pools
- **Device Management**: Multiple OSDs per node
- **Network**: Dedicated storage network (10Gbps+)

### Performance
- **Instance Types**: Storage-optimized (i3, d3, r5d)
- **Storage**: NVMe SSDs, multiple devices per OSD
- **Placement Groups**: Proper PG calculation for scale

### Operations
- **Monitoring**: Prometheus + Grafana dashboards
- **Backup**: Cross-region replication, snapshots
- **Disaster Recovery**: Multi-zone, multi-region setup

---

**Status**: Deployed via ArgoCD GitOps  
**Profile**: `export AWS_PROFILE=oth_infra`  
**Purpose**: Learning Ceph fundamentals
