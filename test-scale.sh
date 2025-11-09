#!/bin/bash
# Test KEDA + Karpenter autoscaling

echo "🚀 Starting scale test..."
echo ""

# Deploy load generator
kubectl run load-generator --image=busybox --restart=Never -- /bin/sh -c "while true; do wget -q -O- http://test-scale.default.svc.cluster.local; done"

echo "📊 Monitoring (Ctrl+C to stop):"
echo ""

while true; do
  clear
  echo "=== Pods ==="
  kubectl get pods -l app=test-scale -o wide
  echo ""
  echo "=== HPA (KEDA) ==="
  kubectl get scaledobject test-scale
  echo ""
  echo "=== Nodes ==="
  kubectl get nodes -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].type,PODS:.status.allocatable.pods
  echo ""
  echo "=== Karpenter NodePool ==="
  kubectl get nodepool
  echo ""
  sleep 5
done
