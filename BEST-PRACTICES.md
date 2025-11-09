# EKS Best Practices - Production-Ready Setup

This document explains the production best practices implemented in this cluster.

## 🎯 Node Separation Strategy

### Problem
When running ArgoCD with Karpenter autoscaling:
- ArgoCD pods could schedule on Karpenter Spot nodes
- Karpenter scales down Spot nodes when workload decreases
- ArgoCD disruption causes cluster management issues

### Solution: Taints + Tolerations + Node Affinity

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     EKS Cluster                             │
│                                                             │
│  ┌──────────────────────────┐  ┌──────────────────────────┐│
│  │   System Nodes           │  │   Karpenter Nodes        ││
│  │   (t3.medium, On-Demand) │  │   (Spot, Auto-scaled)    ││
│  │                          │  │                          ││
│  │  Label:                  │  │  Label:                  ││
│  │  node-role.k8s.io/system │  │  karpenter.sh/capacity   ││
│  │                          │  │                          ││
│  │  Taint:                  │  │  No Taint                ││
│  │  CriticalAddonsOnly      │  │  (Apps can schedule)     ││
│  │  =true:NoSchedule        │  │                          ││
│  │                          │  │                          ││
│  │  ✅ ArgoCD               │  │  ✅ Application Pods     ││
│  │  ✅ Prometheus           │  │  ✅ KEDA scaled pods     ││
│  │  ✅ Grafana              │  │  ✅ User workloads       ││
│  │  ✅ Alertmanager         │  │                          ││
│  │  ❌ App Pods (blocked)   │  │  ❌ ArgoCD (blocked)     ││
│  └──────────────────────────┘  └──────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

## 📋 Implementation Details

### 1. System Node Group Configuration

**Terraform** (`terraform/modules/eks/main.tf`):
```hcl
resource "aws_eks_node_group" "system_nodes" {
  labels = {
    "node-role.kubernetes.io/system" = "true"
  }
  
  taint {
    key    = "CriticalAddonsOnly"
    value  = "true"
    effect = "NO_SCHEDULE"
  }
  
  capacity_type = "ON_DEMAND"  # Never Spot for system nodes
}
```

**What it does:**
- Adds label `node-role.kubernetes.io/system=true` to identify system nodes
- Adds taint `CriticalAddonsOnly=true:NoSchedule` to block app pods
- Uses On-Demand instances for stability (never Spot)

### 2. ArgoCD Configuration

**Terraform** (`terraform/modules/argocd/main.tf`):
```hcl
controller = {
  tolerations = [{
    key      = "CriticalAddonsOnly"
    operator = "Equal"
    value    = "true"
    effect   = "NoSchedule"
  }]
  affinity = {
    nodeAffinity = {
      requiredDuringSchedulingIgnoredDuringExecution = {
        nodeSelectorTerms = [{
          matchExpressions = [{
            key      = "node-role.kubernetes.io/system"
            operator = "Exists"
          }]
        }]
      }
    }
  }
}
```

**What it does:**
- **Toleration**: Allows ArgoCD to schedule on tainted system nodes
- **Node Affinity**: REQUIRES system node label (won't schedule elsewhere)
- Applied to ALL ArgoCD components (controller, server, repo-server, redis, dex, notifications, applicationSet)

### 3. Monitoring Stack Configuration

**Helm values** (`apps/kube-prometheus-stack/values.yaml`):
```yaml
prometheus:
  prometheusSpec:
    tolerations:
      - key: CriticalAddonsOnly
        operator: Equal
        value: "true"
        effect: NoSchedule

grafana:
  tolerations:
    - key: CriticalAddonsOnly
      operator: Equal
      value: "true"
      effect: NoSchedule

alertmanager:
  alertmanagerSpec:
    tolerations:
      - key: CriticalAddonsOnly
        operator: Equal
        value: "true"
        effect: NoSchedule
```

**What it does:**
- Monitoring components CAN run on system nodes
- But they're not REQUIRED to (no node affinity)
- Provides flexibility for scheduling

## 🔒 How It Works

### Scenario 1: App Pod Tries to Schedule

```
1. App pod created (no toleration)
2. Scheduler checks nodes:
   - System nodes: ❌ Taint blocks it
   - Karpenter nodes: ✅ No taint, can schedule
3. Pod schedules on Karpenter node
```

### Scenario 2: ArgoCD Pod Tries to Schedule

```
1. ArgoCD pod created (has toleration + affinity)
2. Scheduler checks nodes:
   - System nodes: ✅ Toleration allows, affinity requires
   - Karpenter nodes: ❌ No system label, affinity blocks
3. Pod schedules on system node
```

### Scenario 3: Karpenter Scales Down

```
1. Workload decreases
2. Karpenter identifies underutilized Spot nodes
3. Karpenter drains and terminates Spot nodes
4. ArgoCD unaffected (on system nodes)
5. ✅ No disruption to cluster management
```

## ✅ Verification

### Check Node Configuration
```bash
kubectl get nodes -o custom-columns=\
NAME:.metadata.name,\
SYSTEM:.metadata.labels.node-role\\.kubernetes\\.io/system,\
TAINT:.spec.taints[0].key
```

Expected output:
```
NAME                                           SYSTEM   TAINT
ip-10-0-37-232.eu-central-1.compute.internal   true     CriticalAddonsOnly
ip-10-0-58-40.eu-central-1.compute.internal    true     CriticalAddonsOnly
ip-10-0-32-35.eu-central-1.compute.internal    <none>   <none>
```

### Check ArgoCD Placement
```bash
kubectl get pods -n argocd -o custom-columns=\
NAME:.metadata.name,\
NODE:.spec.nodeName
```

All ArgoCD pods should be on system nodes (with `true` label).

### Test App Pod Placement
```bash
kubectl run test-app --image=nginx --restart=Never
kubectl get pod test-app -o wide
kubectl delete pod test-app
```

Test pod should schedule on Karpenter node (without system label).

## 📊 Comparison with Other Approaches

### Approach 1: Node Affinity Only (Previous Implementation)
```yaml
nodeAffinity:
  requiredDuringSchedulingIgnoredDuringExecution:
    nodeSelectorTerms:
    - matchExpressions:
      - key: karpenter.sh/capacity-type
        operator: DoesNotExist
```

**Pros:**
- Simple
- Works for small setups

**Cons:**
- ❌ App pods CAN schedule on system nodes (no protection)
- ❌ System nodes can fill up with app pods
- ❌ Not production-ready

### Approach 2: Taints + Tolerations (Current Implementation) ⭐
```yaml
# System nodes
taint:
  key: CriticalAddonsOnly
  effect: NoSchedule

# ArgoCD
tolerations:
  - key: CriticalAddonsOnly
    effect: NoSchedule
affinity:
  nodeAffinity:
    required:
      - key: node-role.kubernetes.io/system
        operator: Exists
```

**Pros:**
- ✅ App pods CANNOT schedule on system nodes (taint blocks)
- ✅ Control plane pods MUST run on system nodes (affinity requires)
- ✅ Clear separation of concerns
- ✅ Industry standard pattern
- ✅ Production-ready

**Cons:**
- Slightly more complex setup

### Approach 3: Separate Management Cluster (Enterprise)
```
Management Cluster:
- ArgoCD
- Monitoring
- Logging

Workload Clusters:
- Applications only
- Fully autoscaled
```

**Pros:**
- ✅ Complete isolation
- ✅ Can manage multiple clusters
- ✅ Best for large organizations

**Cons:**
- ❌ More expensive (2+ clusters)
- ❌ More complex to manage
- ❌ Overkill for most use cases

## 🏢 Industry Standards

### What Big Companies Do

**Netflix, Uber, Airbnb:**
- Separate management cluster for control plane
- Workload clusters fully autoscaled with Karpenter/Cluster Autoscaler

**Medium Companies (100-1000 employees):**
- Dedicated system node group with taints (our approach)
- Karpenter for app nodes only
- Cost-effective and production-ready

**Startups:**
- Node affinity only (simple but not ideal)
- Upgrade to taints when going to production

## 🎓 Key Learnings

### 1. Taints Block, Tolerations Allow
- **Taint**: "Don't schedule here unless you have permission"
- **Toleration**: "I have permission to schedule on tainted nodes"
- **Node Affinity**: "I MUST schedule on specific nodes"

### 2. Taints > Node Affinity for Protection
- Node affinity alone doesn't prevent app pods from using system nodes
- Taints actively block unwanted pods
- Combination of both provides complete control

### 3. System Nodes Should Never Be Spot
- Control plane components need stability
- Spot interruptions cause cluster management issues
- On-Demand instances worth the extra cost for system nodes

### 4. DaemonSets Are Special
- DaemonSets (like node-exporter, promtail) run on ALL nodes
- They tolerate taints automatically
- This is expected and correct behavior

## 🚀 Next Steps

### For Production
- [ ] Add more system nodes for HA (3+ nodes across AZs)
- [ ] Set up PodDisruptionBudgets for ArgoCD
- [ ] Configure backup/restore with Velero
- [ ] Implement Pod Security Standards
- [ ] Set up AWS GuardDuty

### For Cost Optimization
- [ ] Use Spot instances for dev/test workloads
- [ ] Implement Karpenter consolidation policies
- [ ] Set up cost monitoring dashboards
- [ ] Review resource requests/limits

### For Observability
- [ ] Configure Alertmanager notifications (Slack/Email)
- [ ] Set up SLOs and SLIs
- [ ] Implement distributed tracing
- [ ] Add custom Grafana dashboards

## 📚 References

- [EKS Best Practices - Node Management](https://aws.github.io/aws-eks-best-practices/scalability/docs/node-efficiency/)
- [Kubernetes Taints and Tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/)
- [Karpenter Best Practices](https://karpenter.sh/docs/concepts/nodepools/)
- [ArgoCD Production Best Practices](https://argo-cd.readthedocs.io/en/stable/operator-manual/high_availability/)

## 🎯 Summary

**What We Implemented:**
- System node group with label + taint
- ArgoCD with toleration + node affinity
- Monitoring with tolerations (flexible scheduling)

**Benefits:**
- ✅ Control plane protected from autoscaling disruption
- ✅ App pods can't consume system node resources
- ✅ Clear separation between system and app workloads
- ✅ Production-ready, industry-standard pattern
- ✅ Cost-effective (no separate cluster needed)

**Result:**
A production-ready EKS cluster with proper workload isolation! 🎉
