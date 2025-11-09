# Real-time CloudTrail Observability

## Overview
This module provides real-time CloudTrail logging to CloudWatch with visualization dashboards.

## Features
- ✅ Real-time API call logging (no 15-min delay)
- ✅ CloudWatch Insights queries
- ✅ Pre-built dashboard
- ✅ EventBridge integration

## Cost
~$2-3/month for typical EKS cluster

## Access Dashboard
```bash
# Open in AWS Console
aws cloudwatch get-dashboard --dashboard-name eks-lab-argocd-operations --region eu-central-1
```

Or visit: https://console.aws.amazon.com/cloudwatch/home?region=eu-central-1#dashboards:name=eks-lab-argocd-operations

## CloudWatch Insights Queries

### 1. All EKS API Calls (Last Hour)
```
SOURCE '/aws/cloudtrail/eks-lab-argocd'
| fields @timestamp, eventName, userIdentity.principalId, sourceIPAddress
| filter eventSource = "eks.amazonaws.com"
| sort @timestamp desc
| limit 100
```

### 2. Node Group Operations
```
SOURCE '/aws/cloudtrail/eks-lab-argocd'
| fields @timestamp, eventName, requestParameters.nodegroupName, responseElements.nodegroup.status
| filter eventName in ["CreateNodegroup", "DeleteNodegroup", "UpdateNodegroupConfig"]
| sort @timestamp desc
```

### 3. Failed API Calls
```
SOURCE '/aws/cloudtrail/eks-lab-argocd'
| fields @timestamp, eventName, errorCode, errorMessage
| filter eventSource = "eks.amazonaws.com" and ispresent(errorCode)
| sort @timestamp desc
```

### 4. Who Did What (Audit)
```
SOURCE '/aws/cloudtrail/eks-lab-argocd'
| fields @timestamp, eventName, userIdentity.principalId, userIdentity.arn
| filter eventSource = "eks.amazonaws.com"
| stats count() by eventName, userIdentity.principalId
```

### 5. Cluster Creation Timeline
```
SOURCE '/aws/cloudtrail/eks-lab-argocd'
| fields @timestamp, eventName, requestParameters.name
| filter eventName = "CreateCluster"
| sort @timestamp asc
```

## CLI Access

### Query logs in real-time
```bash
aws logs tail /aws/cloudtrail/eks-lab-argocd --follow --region eu-central-1
```

### Run Insights query
```bash
aws logs start-query \
  --log-group-name /aws/cloudtrail/eks-lab-argocd \
  --start-time $(date -u -d '1 hour ago' +%s) \
  --end-time $(date +%s) \
  --query-string 'fields @timestamp, eventName | filter eventSource = "eks.amazonaws.com" | sort @timestamp desc' \
  --region eu-central-1
```

## Visualization Options

### 1. AWS Console (Built-in)
- CloudWatch Dashboard (auto-created)
- CloudWatch Insights (query interface)

### 2. Grafana (Open Source)
Already included in your setup! Add CloudWatch data source:
```yaml
datasources:
  - name: CloudWatch
    type: cloudwatch
    jsonData:
      defaultRegion: eu-central-1
      logGroups:
        - name: /aws/cloudtrail/eks-lab-argocd
```

### 3. CLI (Terminal)
```bash
# Watch EKS events live
aws logs tail /aws/cloudtrail/eks-lab-argocd \
  --follow \
  --filter-pattern '{ $.eventSource = "eks.amazonaws.com" }' \
  --region eu-central-1
```

## Best Practices
- ✅ 7-day retention (cost-effective for learning)
- ✅ EventBridge for real-time alerts
- ✅ CloudWatch Insights for ad-hoc queries
- ✅ Grafana for long-term visualization
