# EKS Lab with ArgoCD - Production-Ready Setup

Complete production-ready EKS cluster with GitOps (ArgoCD), autoscaling (KEDA + Karpenter), monitoring (Prometheus/Grafana), logging (Loki), and best practices for workload isolation.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              EKS Cluster                                │
│                                                                         │
│  ┌────────────────────────────┐    ┌────────────────────────────────┐ │
│  │   System Nodes             │    │   Karpenter Nodes              │ │
│  │   (t3.medium, On-Demand)   │    │   (Spot, Auto-scaled)          │ │
│  │                            │    │                                │ │
│  │  Label: system=true        │    │  Label: karpenter.sh/capacity  │ │
│  │  Taint: CriticalAddonsOnly │    │  No Taint                      │ │
│  │                            │    │                                │ │
│  │  ✅ ArgoCD                 │    │  ✅ Application Pods           │ │
│  │  ✅ Prometheus/Grafana     │    │  ✅ KEDA scaled workloads      │ │
│  │  ✅ Alertmanager           │    │  ✅ User workloads             │ │
│  │  ❌ App Pods (blocked)     │    │  ❌ ArgoCD (blocked)           │ │
│  └────────────────────────────┘    └────────────────────────────────┘ │
│                                                                         │
│  Autoscaling Flow:                                                     │
│  High CPU → KEDA scales pods → Pods pending → Karpenter adds nodes    │
└─────────────────────────────────────────────────────────────────────────┘
```

## 📦 Components

### Infrastructure (Terraform)
- **VPC**: Custom VPC with public/private subnets across 2 AZs
- **EKS Cluster**: Kubernetes 1.34
- **System Nodes**: 2x t3.medium On-Demand (tainted for control plane only)
- **Karpenter**: Node autoscaling with Spot instances (70% cost savings)
- **Add-ons**: Metrics Server, CoreDNS, VPC-CNI, kube-proxy
- **IAM**: IRSA for Grafana CloudWatch, Karpenter roles

### Applications (ArgoCD)
- **ArgoCD**: GitOps continuous delivery (30s sync, on system nodes)
- **KEDA**: Pod autoscaling (1-20 replicas, CPU/Memory triggers)
- **Prometheus + Grafana**: Metrics and dashboards
- **Loki + Promtail**: Log aggregation
- **Alertmanager**: Alert routing

### Key Features
- ✅ **Workload Isolation**: Taints + tolerations prevent app pods on system nodes
- ✅ **Cost Optimization**: Karpenter Spot instances, no CloudWatch Observability ($50-200/month saved)
- ✅ **Auto-scaling**: KEDA scales pods, Karpenter scales nodes
- ✅ **GitOps**: All apps managed via ArgoCD
- ✅ **Production-Ready**: Industry standard patterns

## 🚀 Quick Start

### Prerequisites
```bash
# Required
- AWS CLI configured with profile `oth_infra`
- Terraform >= 1.0
- kubectl
- Git
```

### 1. Deploy Infrastructure
```bash
cd terraform
terraform init

# Set GitHub token for ArgoCD private repo access
export TF_VAR_github_token="ghp_your_token_here"

terraform apply
```

### 2. Configure kubectl
```bash
aws eks update-kubeconfig --region eu-central-1 --name eks-lab-argocd --profile oth_infra
```

### 3. Verify Setup
```bash
# Check nodes (2 system + Karpenter nodes)
kubectl get nodes -o custom-columns=NAME:.metadata.name,SYSTEM:.metadata.labels.node-role\\.kubernetes\\.io/system,TAINT:.spec.taints[0].key

# Check ArgoCD (should be on system nodes)
kubectl get pods -n argocd -o wide

# Check apps
kubectl get application -n argocd
```

### 4. Access ArgoCD
```bash
# Get password
kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d

# Port forward
kubectl port-forward -n argocd svc/argocd-server 8080:443

# Open https://localhost:8080 (admin / <password>)
```

### 5. Access Grafana
```bash
# Get password
kubectl get secret -n monitoring monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 -d

# Port forward
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80

# Open http://localhost:3000 (admin / <password>)
```

## 🎯 Autoscaling (KEDA + Karpenter)

### How It Works
```
1. KEDA monitors CPU/Memory
2. CPU > 50% → KEDA scales pods (1 → 20)
3. Pods pending → Karpenter provisions Spot nodes
4. Workload decreases → KEDA scales down pods
5. Nodes underutilized → Karpenter consolidates (removes nodes)
```

### KEDA Configuration
```yaml
minReplicaCount: 1
maxReplicaCount: 20
triggers:
  - type: cpu
    metadata:
      value: "50"    # Scale at 50% CPU
  - type: memory
    metadata:
      value: "50"    # Scale at 50% Memory
```

### Karpenter Configuration
```yaml
limits:
  cpu: 10          # Max ~5 t3.small nodes
  memory: 20Gi
requirements:
  - key: karpenter.sh/capacity-type
    values: ["spot", "on-demand"]  # Prefer Spot (70% cheaper)
consolidation:
  enabled: true
  after: 1m        # Remove empty nodes after 1 minute
```

### Test Autoscaling
```bash
# Create test workload
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stress-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: stress
  template:
    metadata:
      labels:
        app: stress
    spec:
      containers:
      - name: stress
        image: polinux/stress
        args: ["--cpu", "1"]
        resources:
          requests:
            cpu: 500m
            memory: 256Mi
---
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: stress-test
spec:
  scaleTargetRef:
    name: stress-test
  minReplicaCount: 1
  maxReplicaCount: 20
  triggers:
  - type: cpu
    metadata:
      value: "50"
EOF

# Watch scaling
watch kubectl get pods,nodes
```

## 🔒 Best Practices - Workload Isolation

### System Nodes (Control Plane)
```yaml
# Terraform configuration
labels = {
  "node-role.kubernetes.io/system" = "true"
}
taint {
  key    = "CriticalAddonsOnly"
  value  = "true"
  effect = "NO_SCHEDULE"
}
```

### ArgoCD (Runs on System Nodes)
```yaml
tolerations:
  - key: CriticalAddonsOnly
    operator: Equal
    value: "true"
    effect: NoSchedule
affinity:
  nodeAffinity:
    required:
      - key: node-role.kubernetes.io/system
        operator: Exists
```

### Result
- **App pods**: Blocked by taint → Schedule on Karpenter nodes ✅
- **ArgoCD**: Tolerate taint + require label → System nodes only ✅
- **Karpenter scales down**: Only removes Spot nodes → ArgoCD unaffected ✅

### Why This Matters
- Control plane components stay stable (no Spot interruptions)
- App pods can't consume system node resources
- Industry standard pattern (Netflix, Uber use similar approach)

## 📊 Monitoring & Dashboards

### Grafana Dashboards
- **EKS Cluster Overview**: Node/Pod CPU/Memory, Top 10 pods
- **AWS Cost Dashboard**: Estimated charges from CloudWatch
- **30+ Built-in**: Kubernetes resources, CoreDNS, etcd, API server

### Prometheus Metrics
- Node metrics (CPU, memory, disk, network)
- Pod metrics (resource usage, restarts)
- Karpenter metrics (node provisioning, consolidation)
- KEDA metrics (scaling events, triggers)

### Loki Logs
```bash
# Query in Grafana
{namespace="monitoring"}
{app="argocd-server"} |= "error"
```

## 💰 Cost Optimization

### Monthly Costs (~$180)
| Resource | Cost |
|----------|------|
| EKS Control Plane | $73 |
| System Nodes (2x t3.medium) | ~$60 |
| Karpenter Spot Nodes | ~$10-30 (varies) |
| NAT Gateway | ~$32 |
| EBS Volumes | ~$10 |
| **Total** | **~$180/month** |

### Cost Savings
- ✅ Removed CloudWatch Observability: **-$50-200/month**
- ✅ Karpenter Spot instances: **-70% vs On-Demand**
- ✅ Auto-consolidation: Removes unused nodes
- ✅ Prometheus (free) instead of CloudWatch

## 🔧 Common Operations

### Scale Manually
```bash
# Scale deployment
kubectl scale deployment <name> --replicas=5

# Scale node group (system nodes)
aws eks update-nodegroup-config \
  --cluster-name eks-lab-argocd \
  --nodegroup-name eks-lab-argocd-system-nodes \
  --scaling-config desiredSize=3
```

### Check Resource Usage
```bash
kubectl top nodes
kubectl top pods -A
```

### View Logs
```bash
# Pod logs
kubectl logs -n <namespace> <pod-name>

# Karpenter logs
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter

# KEDA logs
kubectl logs -n keda -l app=keda-operator
```

### Sync ArgoCD App
```bash
# Via CLI
kubectl patch application <app-name> -n argocd \
  --type merge -p '{"operation":{"sync":{"revision":"HEAD"}}}'

# Or via UI: Applications → <app> → Sync
```

## 🛡️ Security Best Practices

### Implemented
- ✅ Private subnets for worker nodes
- ✅ IAM roles with least privilege (IRSA)
- ✅ Security groups with minimal access
- ✅ Workload isolation (taints + tolerations)
- ✅ Secrets in Kubernetes Secrets

### Recommended for Production
- [ ] Enable AWS GuardDuty
- [ ] Set up AWS Config rules
- [ ] Implement Pod Security Standards
- [ ] Enable audit logging
- [ ] Set up AWS WAF for ALB

## 🔍 Troubleshooting

### Pods Pending
```bash
# Check events
kubectl describe pod <pod-name>

# Check node capacity
kubectl get nodes -o custom-columns=NAME:.metadata.name,PODS:.status.allocatable.pods

# Check Karpenter logs
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --tail=50
```

### ArgoCD Out of Sync
```bash
# Check status
kubectl get application -n argocd

# Force sync
kubectl patch application <app-name> -n argocd \
  --type merge -p '{"operation":{"sync":{"revision":"HEAD"}}}'
```

### Karpenter Not Scaling
```bash
# Check NodePool
kubectl get nodepool -o yaml

# Check pending pods
kubectl get pods -A | grep Pending

# Check Karpenter events
kubectl get events -n karpenter --sort-by='.lastTimestamp'
```

## 📁 Project Structure

```
eks-lab-argocd/
├── terraform/                      # Infrastructure as Code
│   ├── main.tf
│   ├── modules/
│   │   ├── vpc/                    # VPC module
│   │   ├── eks/                    # EKS cluster + Karpenter
│   │   └── argocd/                 # ArgoCD bootstrap
│   └── terraform.tfvars
│
├── apps/                           # Helm charts
│   ├── kube-prometheus-stack/      # Monitoring
│   ├── loki/                       # Logging
│   ├── promtail/                   # Log shipper
│   └── keda/                       # Pod autoscaling
│
├── argocd-apps/                    # ArgoCD Applications
│   ├── monitoring.yaml
│   ├── keda.yaml
│   ├── karpenter.yaml
│   └── loki.yaml
│
└── README.md                       # This file
```

## 🗑️ Cleanup

### Proper Destroy Order

**Important:** Delete Karpenter first to avoid Spot instance conflicts.

```bash
# Option 1: Using Makefile (recommended)
make destroy

# Option 2: Manual steps
kubectl delete application karpenter -n argocd
sleep 60  # Wait for nodes to terminate
cd terraform && terraform destroy
```

### Quick Cleanup (if stuck)
```bash
make clean  # Force delete Karpenter resources
```

## 🚧 Roadmap

- [ ] Add HPA for other workloads
- [ ] Configure Alertmanager notifications (Slack/Email)
- [ ] Implement Network Policies
- [ ] Add Velero for backups
- [ ] Set up external-dns
- [ ] Add cert-manager for TLS

## 📚 References

- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Karpenter Documentation](https://karpenter.sh/docs/)
- [KEDA Documentation](https://keda.sh/docs/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)

## 🎓 Key Learnings

1. **Taints + Tolerations**: Industry standard for workload isolation
2. **KEDA + Karpenter**: Perfect combo for cost-effective autoscaling
3. **Prometheus > CloudWatch**: Free, open-source, industry standard
4. **GitOps with ArgoCD**: Declarative, auditable, easy rollbacks
5. **Spot Instances**: 70% savings with Karpenter handling interruptions

## 👤 Author

Built with ❤️ for learning production-ready EKS, GitOps, and cloud-native best practices.
# CI/CD Pipeline Test

## CI/CD Pipeline Status
- ✅ GitHub Actions configured
- ✅ AWS OIDC authentication
- ✅ Terraform automation
- ✅ S3 backend with native locking

## Fresh Deployment with S3 Backend
