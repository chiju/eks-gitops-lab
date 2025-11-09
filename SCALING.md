# Autoscaling with KEDA + Karpenter

## Overview

This cluster uses **two autoscalers** working together:

1. **KEDA** - Scales **pods** based on metrics (CPU, memory, events)
2. **Karpenter** - Scales **nodes** based on pending pods

## How It Works

```
High CPU/Memory → KEDA scales pods → Pods pending → Karpenter adds nodes
```

## KEDA (Pod Autoscaling)

**What triggers KEDA:**
- CPU usage > 50%
- Memory usage > 60%
- Custom metrics (queues, HTTP requests, etc.)

**Configuration:**
```yaml
spec:
  minReplicaCount: 1
  maxReplicaCount: 30
  triggers:
  - type: cpu
    metadata:
      value: "50"      # Scale when CPU > 50%
  - type: memory
    metadata:
      value: "60"      # Scale when Memory > 60%
```

**Example:**
```
1 pod at 30% CPU  → No scaling
1 pod at 60% CPU  → KEDA scales to 2 pods
2 pods at 60% CPU → KEDA scales to 4 pods
4 pods at 30% CPU → KEDA scales down to 2 pods
```

## Karpenter (Node Autoscaling)

**What triggers Karpenter:**
- ✅ **Pending pods** (cannot be scheduled on existing nodes)
- That's it! One simple trigger.

**Why pods become pending:**
- Node at max pod capacity (17 pods for t3.medium)
- Not enough CPU/memory on existing nodes
- Node affinity/taints don't match

**Configuration:**
```yaml
spec:
  limits:
    cpu: 10          # Max 10 CPUs across all Karpenter nodes
    memory: 20Gi     # Max 20Gi memory (~5 t3.small nodes)
  
  requirements:
    - key: karpenter.sh/capacity-type
      values: ["spot", "on-demand"]  # Prefer Spot (70% cheaper)
```

**Example:**
```
All nodes full → Pod pending → Karpenter provisions Spot node → Pod scheduled
```

## Cost Optimization

**Spot Instances:**
- 70-90% cheaper than On-Demand
- Karpenter handles interruptions automatically
- Falls back to On-Demand if Spot unavailable

**Auto-Consolidation:**
- Karpenter moves pods to fewer nodes when possible
- Terminates empty nodes after 1 minute
- Saves money by reducing node count

## Limits (Prevent Abuse)

**Karpenter Limits:**
```yaml
limits:
  cpu: 10          # Max ~5 t3.small nodes
  memory: 20Gi
```

**KEDA Limits:**
```yaml
maxReplicaCount: 30  # Max 30 pods
```

**Why limits matter:**
- Prevent runaway scaling
- Control costs
- Avoid hitting AWS quotas

## Test Scaling

Run the test script:
```bash
./test-scale.sh
```

**What you'll see:**

1. **Initial state:** 1 pod, 3 nodes
2. **CPU load starts:** Pod uses 250% CPU (>50% threshold)
3. **KEDA scales:** 1 → 4 pods
4. **Pods pending:** Not enough capacity on nodes
5. **Karpenter scales:** Provisions Spot node
6. **Pods scheduled:** All pods running
7. **Load stops:** KEDA scales down
8. **Nodes empty:** Karpenter consolidates (removes unused nodes)

## Monitoring

**Check pod scaling:**
```bash
kubectl get hpa keda-hpa-test-scale
kubectl top pods -l app=test-scale
```

**Check node scaling:**
```bash
kubectl get nodepool
kubectl get nodes -o custom-columns=NAME:.metadata.name,INSTANCE:.metadata.labels.node\\.kubernetes\\.io/instance-type,CAPACITY:.metadata.labels.karpenter\\.sh/capacity-type
```

**Check pending pods (triggers Karpenter):**
```bash
kubectl get pods --field-selector=status.phase=Pending
```

## Real-World Use Cases

**KEDA triggers:**
- CPU/Memory (like our test)
- SQS queue length
- Kafka lag
- HTTP requests per second
- Cron schedules
- Prometheus metrics

**Karpenter benefits:**
- Faster scaling than Cluster Autoscaler (seconds vs minutes)
- Better bin-packing (more efficient node usage)
- Spot instance support with automatic fallback
- No need to pre-define node groups

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Application Load                     │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│                    KEDA (Watches)                       │
│  • CPU/Memory metrics                                   │
│  • Custom metrics (SQS, Kafka, etc.)                    │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│              Scales Deployment (Pods)                   │
│  1 pod → 2 pods → 4 pods → 8 pods                      │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│              Some Pods Pending?                         │
│  (Not enough node capacity)                             │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│              Karpenter (Watches)                        │
│  • Pending pods                                         │
│  • Node utilization                                     │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│              Provisions New Nodes                       │
│  • Spot instances (70% cheaper)                         │
│  • Right-sized for workload                             │
│  • Auto-consolidates when idle                          │
└─────────────────────────────────────────────────────────┘
```

## Summary

**KEDA:**
- Scales **pods** based on **metrics**
- Fast (seconds)
- Flexible triggers

**Karpenter:**
- Scales **nodes** based on **pending pods**
- Fast (30-60 seconds)
- Cost-optimized (Spot instances)

**Together:**
- Complete autoscaling solution
- Cost-effective
- Production-ready
