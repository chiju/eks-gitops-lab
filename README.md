# EKS Lab with ArgoCD - Production-Ready Setup

Complete EKS cluster setup with GitOps (ArgoCD), monitoring (Prometheus/Grafana), logging (Loki), and cost optimization following AWS best practices.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS Cloud                               │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │                    VPC (10.0.0.0/16)                      │ │
│  │                                                           │ │
│  │  ┌──────────────────┐      ┌──────────────────┐         │ │
│  │  │  Public Subnet   │      │  Public Subnet   │         │ │
│  │  │  10.0.1.0/24     │      │  10.0.2.0/24     │         │ │
│  │  │  (AZ-1)          │      │  (AZ-2)          │         │ │
│  │  │  - NAT Gateway   │      │                  │         │ │
│  │  │  - Internet GW   │      │                  │         │ │
│  │  └──────────────────┘      └──────────────────┘         │ │
│  │           │                         │                    │ │
│  │  ┌──────────────────┐      ┌──────────────────┐         │ │
│  │  │ Private Subnet   │      │ Private Subnet   │         │ │
│  │  │ 10.0.37.0/24     │      │ 10.0.60.0/24     │         │ │
│  │  │ (AZ-1)           │      │ (AZ-2)           │         │ │
│  │  │                  │      │                  │         │ │
│  │  │ ┌──────────────┐ │      │ ┌──────────────┐ │         │ │
│  │  │ │ EKS Nodes    │ │      │ │ EKS Nodes    │ │         │ │
│  │  │ │ t3.medium    │ │      │ │ t3.medium    │ │         │ │
│  │  │ └──────────────┘ │      │ └──────────────┘ │         │ │
│  │  └──────────────────┘      └──────────────────┘         │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │                    EKS Control Plane                      │ │
│  │                    (AWS Managed)                          │ │
│  └───────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## 📦 Components

### Infrastructure (Terraform)
- **VPC**: Custom VPC with public/private subnets across 2 AZs
- **EKS Cluster**: Kubernetes 1.34 with managed node groups
- **Add-ons**: 
  - Metrics Server (for HPA and `kubectl top`)
  - CoreDNS, VPC-CNI, kube-proxy
- **IAM**: IRSA for Grafana CloudWatch access

### Applications (ArgoCD)
- **ArgoCD**: GitOps continuous delivery
- **Prometheus + Grafana**: Metrics and dashboards
- **Loki + Promtail**: Log aggregation
- **NGINX**: Sample application

### Monitoring Stack
- **Prometheus**: Metrics collection (industry standard)
- **Grafana**: Visualization with custom dashboards
- **Alertmanager**: Alert routing
- **Node Exporter**: Node-level metrics

### Logging Stack
- **Loki**: Log aggregation (Prometheus for logs)
- **Promtail**: Log shipper (DaemonSet)

## 🚀 Quick Start

### Prerequisites
- AWS CLI configured with profile `oth_infra`
- Terraform >= 1.0
- kubectl
- Git

### 1. Deploy Infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

**Resources created:**
- VPC with 2 public + 2 private subnets
- NAT Gateway, Internet Gateway
- EKS cluster with 2 t3.medium nodes
- IAM roles and policies
- Security groups

### 2. Configure kubectl

```bash
aws eks update-kubeconfig --region eu-central-1 --name eks-lab-argocd --profile oth_infra
```

### 3. Verify Cluster

```bash
kubectl get nodes
kubectl get pods -A
```

### 4. Access ArgoCD

```bash
# Get admin password
kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d

# Port forward
kubectl port-forward -n argocd svc/argocd-server 8080:443

# Open browser
open https://localhost:8080
# Username: admin
```

### 5. Access Grafana

```bash
# Get admin password
kubectl get secret -n monitoring monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 -d

# Port forward
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80

# Open browser
open http://localhost:3000
# Username: admin
```

## 📁 Project Structure

```
eks-lab-argocd/
├── terraform/                      # Infrastructure as Code
│   ├── main.tf                     # Root module
│   ├── modules/
│   │   ├── vpc/                    # VPC module
│   │   ├── eks/                    # EKS cluster module
│   │   └── argocd/                 # ArgoCD bootstrap module
│   └── terraform.tfvars            # Variables
│
├── apps/                           # Helm charts for applications
│   ├── kube-prometheus-stack/      # Monitoring stack
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   ├── dashboards/             # Grafana dashboards (JSON)
│   │   │   ├── eks-prometheus-dashboard.json
│   │   │   └── aws-cost-dashboard.json
│   │   └── templates/
│   │       ├── _helpers.tpl        # Helm helpers
│   │       └── configmaps/
│   │           └── dashboards.yaml # Dashboard ConfigMaps
│   ├── loki/                       # Log aggregation
│   ├── promtail/                   # Log shipper
│   └── nginx/                      # Sample app
│
├── argocd-apps/                    # ArgoCD Application manifests
│   ├── monitoring.yaml
│   ├── loki.yaml
│   ├── promtail.yaml
│   └── nginx.yaml
│
├── cost-monitor.py                 # Cost monitoring script
├── cost-optimizer.py               # Cost optimization script
└── README.md                       # This file
```

## 🎯 Key Features

### GitOps with ArgoCD
- **Declarative**: All apps defined in Git
- **Automated sync**: Changes auto-deployed
- **Self-healing**: Drift detection and correction
- **Rollback**: Easy rollback to previous versions

### Monitoring (Industry Standard)
- **Prometheus**: Metrics storage and querying
- **Grafana**: 30+ pre-built dashboards
- **Custom dashboards**: EKS cluster overview, AWS costs
- **Metrics Server**: `kubectl top` support

### Cost Optimization
- **No CloudWatch Observability**: Saves $50-200/month
- **Prometheus instead**: Free, open-source
- **CloudWatch only for**: Billing metrics (free)
- **Cost monitoring scripts**: Track and optimize spend

### High Availability
- **Multi-AZ**: Nodes across 2 availability zones
- **Auto-scaling**: Node group can scale 1-3 nodes
- **Health checks**: Liveness and readiness probes
- **Self-healing**: Kubernetes restarts failed pods

## 📊 Dashboards

### EKS Cluster Overview (Prometheus)
- Node CPU & Memory usage
- Top 10 Pods by CPU & Memory
- Total Nodes, Pods, Running/Failed Pods
- Real-time metrics from Prometheus

### AWS Cost Dashboard
- Estimated charges from CloudWatch
- EC2 instance costs
- Network traffic costs
- Memory usage per instance

### Built-in Dashboards (30+)
- Kubernetes resources
- Node metrics
- Persistent volumes
- CoreDNS, etcd, API server
- And more...

## 🔧 Common Operations

### Scale Node Group

```bash
# Via AWS CLI
aws eks update-nodegroup-config \
  --cluster-name eks-lab-argocd \
  --nodegroup-name eks-lab-argocd-system-nodes \
  --scaling-config minSize=2,maxSize=4,desiredSize=3 \
  --region eu-central-1 \
  --profile oth_infra
```

### Add New Dashboard

1. Create JSON file:
```bash
apps/kube-prometheus-stack/dashboards/my-dashboard.json
```

2. Add to `templates/configmaps/dashboards.yaml`:
```yaml
---
{{- include "dashboard.configmap" (dict "name" "my-dashboard" "file" "dashboards/my-dashboard.json" "root" .) }}
```

3. Commit and push - ArgoCD deploys automatically!

### View Logs

```bash
# Pod logs
kubectl logs -n <namespace> <pod-name>

# Logs via Loki (in Grafana)
# Datasource: Loki
# Query: {namespace="monitoring"}
```

### Check Resource Usage

```bash
# Node resources
kubectl top nodes

# Pod resources
kubectl top pods -A

# Specific namespace
kubectl top pods -n monitoring
```

### Sync ArgoCD Application

```bash
# Via CLI
kubectl patch application monitoring -n argocd \
  --type merge \
  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'

# Or via UI
# Applications → monitoring → Sync
```

## 💰 Cost Breakdown

### Monthly Costs (Estimated)

| Resource | Cost |
|----------|------|
| EKS Control Plane | $73 |
| EC2 Instances (2x t3.medium) | ~$60 |
| NAT Gateway | ~$32 |
| EBS Volumes | ~$10 |
| Data Transfer | ~$5 |
| **Total** | **~$180/month** |

### Cost Savings
- ❌ Removed CloudWatch Observability: **-$50-200/month**
- ✅ Using Prometheus instead: **Free**
- ✅ CloudWatch billing metrics: **Free**

## 🛡️ Security Best Practices

### Implemented
- ✅ Private subnets for worker nodes
- ✅ IAM roles with least privilege (IRSA)
- ✅ Security groups with minimal access
- ✅ VPC Flow Logs enabled
- ✅ EKS cluster endpoint private access
- ✅ Secrets stored in Kubernetes Secrets

### Recommended
- [ ] Enable AWS GuardDuty
- [ ] Set up AWS Config rules
- [ ] Implement Pod Security Standards
- [ ] Enable audit logging
- [ ] Set up AWS WAF for ALB

## 🔍 Troubleshooting

### Pods Pending (Too Many Pods)
```bash
# Check node capacity
kubectl get nodes -o custom-columns=NAME:.metadata.name,PODS:.status.allocatable.pods

# Scale node group
aws eks update-nodegroup-config --cluster-name eks-lab-argocd \
  --nodegroup-name eks-lab-argocd-system-nodes \
  --scaling-config desiredSize=3 \
  --region eu-central-1 --profile oth_infra
```

### ArgoCD Out of Sync
```bash
# Check application status
kubectl get application -n argocd

# Force sync
kubectl patch application <app-name> -n argocd \
  --type merge -p '{"operation":{"sync":{"revision":"HEAD"}}}'
```

### Grafana Dashboard Not Showing
```bash
# Check ConfigMap
kubectl get configmap -n monitoring -l grafana_dashboard=1

# Check Grafana logs
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana
```

### Prometheus Not Scraping
```bash
# Check ServiceMonitor
kubectl get servicemonitor -A

# Check Prometheus targets
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
# Open http://localhost:9090/targets
```

## 🚧 Roadmap

- [ ] Add Horizontal Pod Autoscaler (HPA)
- [ ] Set up Alertmanager notifications (Slack/Email)
- [ ] Implement Network Policies
- [ ] Add Velero for backups
- [ ] Set up external-dns for DNS automation
- [ ] Add cert-manager for TLS certificates
- [ ] Implement Kyverno for policy enforcement

## 📚 References

- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Loki Documentation](https://grafana.com/docs/loki/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📝 License

MIT License - feel free to use this for learning and production!

## 👤 Author

Built with ❤️ for learning EKS, GitOps, and cloud-native best practices.
