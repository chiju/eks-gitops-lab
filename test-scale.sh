#!/bin/bash
# Test KEDA + Karpenter autoscaling

echo "🚀 Starting scale test..."
echo ""
echo "📊 Monitoring (Ctrl+C to stop):"
echo ""
echo "What triggers scaling:"
echo "  KEDA (Pods):      CPU >50% OR Memory >60%"
echo "  Karpenter (Nodes): Pending pods (no capacity)"
echo ""

while true; do
  clear
  echo "=== Pods (KEDA scales these) ==="
  kubectl get pods -l app=test-scale -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,CPU:.spec.containers[0].resources.requests.cpu,MEMORY:.spec.containers[0].resources.requests.memory,NODE:.spec.nodeName | head -15
  
  echo ""
  echo "=== Resource Usage ==="
  kubectl top pods -l app=test-scale 2>/dev/null | head -10 || echo "Metrics not ready yet..."
  
  echo ""
  echo "=== HPA Status (KEDA) ==="
  kubectl get hpa keda-hpa-test-scale -o custom-columns=NAME:.metadata.name,TARGETS:.status.currentMetrics[*].resource.current.averageUtilization,REPLICAS:.status.currentReplicas,DESIRED:.status.desiredReplicas 2>/dev/null || echo "HPA not ready yet..."
  
  echo ""
  echo "=== Nodes (Karpenter scales these) ==="
  kubectl get nodes -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].type,INSTANCE:.metadata.labels.node\\.kubernetes\\.io/instance-type,CAPACITY:.metadata.labels.karpenter\\.sh/capacity-type,PODS:.status.allocatable.pods
  
  echo ""
  echo "=== Karpenter NodePool ==="
  kubectl get nodepool -o custom-columns=NAME:.metadata.name,NODES:.status.resources.nodes,CPU:.status.resources.cpu,MEMORY:.status.resources.memory,READY:.status.conditions[0].status
  
  echo ""
  echo "=== Pending Pods (triggers Karpenter) ==="
  kubectl get pods -l app=test-scale --field-selector=status.phase=Pending 2>/dev/null | tail -n +2 | wc -l | xargs echo "Pending pods:"
  
  sleep 5
done
