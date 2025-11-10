# Working Karpenter 1.8.2 Installation

## Prerequisites
1. IAM role trust policy must allow kube-system namespace:
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::432801802107:oidc-provider/oidc.eks.eu-central-1.amazonaws.com/id/BE0F3FEABAA778D3BC9205B78F24F8C7"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "oidc.eks.eu-central-1.amazonaws.com/id/BE0F3FEABAA778D3BC9205B78F24F8C7:sub": "system:serviceaccount:kube-system:karpenter",
        "oidc.eks.eu-central-1.amazonaws.com/id/BE0F3FEABAA778D3BC9205B78F24F8C7:aud": "sts.amazonaws.com"
      }
    }
  }]
}
```

## Installation Steps

### 1. Install Karpenter Helm Chart
```bash
helm install karpenter oci://public.ecr.aws/karpenter/karpenter \
  --version 1.8.2 \
  --namespace kube-system \
  --values values.yaml
```

### 2. Apply NodePool and EC2NodeClass
```bash
kubectl apply -f nodepool.yaml
kubectl apply -f ec2nodeclass.yaml
```

## Key Configuration Points

### Version
- **Karpenter**: 1.8.2 (NOT 1.8.0 - has AL2023 bug)

### Namespace
- **Must be**: kube-system (official recommendation)
- **Why**: Better integration, proper IRSA setup

### IAM Role
- **Controller Role**: KarpenterControllerRole-eks-lab-argocd
- **Node Role**: eks-lab-argocd-node-group-role (must exist)

### AMI Selection
- **Use**: `alias: al2023@latest`
- **Don't**: Specify custom userData or specific AMI IDs
- **Why**: Let Karpenter auto-generate correct nodeadm configuration

## Verification

Check Karpenter is running:
```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=karpenter
```

Check NodePool and EC2NodeClass:
```bash
kubectl get nodepool,ec2nodeclass
```

Scale a deployment to test:
```bash
kubectl scale deployment test-scale-load --replicas=5
```

Watch nodes being created:
```bash
kubectl get nodes -w
```

## Troubleshooting

### Pods CrashLoopBackOff
- Check IRSA trust policy matches namespace
- Verify ServiceAccount annotation

### Nodes not joining
- Check EC2NodeClass is Ready
- Verify role name exists
- Check Karpenter logs: `kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter`

### No nodes provisioned
- Check for pending pods
- Verify NodePool limits
- Check NodePool requirements match pod requirements
