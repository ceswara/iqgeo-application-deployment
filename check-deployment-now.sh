#!/bin/bash
OUTPUT_FILE="deployment-check-$(date +%Y%m%d-%H%M%S).txt"

{
echo "========================================="
echo "Complete Deployment Check - $(date)"
echo "========================================="
echo ""

echo "=== 1. PVC Status ==="
kubectl get pvc -n iqgeo -o wide
echo ""

echo "=== 2. Pod Status ==="
kubectl get pods -n iqgeo -o wide
echo ""

POD_NAME=$(kubectl get pods -n iqgeo -l app=iqgeo-platform --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}' 2>/dev/null)
echo "Current pod: $POD_NAME"
echo ""

echo "=== 3. ConfigMap - Database Configuration ==="
echo "Checking if MYW_DB_HOST and PGHOST are set correctly..."
kubectl get configmap iqgeo-platform-configmap -n iqgeo -o jsonpath='{.data}' | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(f\"MYW_DB_HOST: '{data.get('MYW_DB_HOST', 'NOT SET')}'\" )
print(f\"MYW_DB_PORT: '{data.get('MYW_DB_PORT', 'NOT SET')}'\")
print(f\"MYW_DB_USERNAME: '{data.get('MYW_DB_USERNAME', 'NOT SET')}'\")
print(f\"PGHOST: '{data.get('PGHOST', 'NOT SET')}'\")
print(f\"PGUSER: '{data.get('PGUSER', 'NOT SET')}'\")
" 2>&1
echo ""

echo "=== 4. Full ConfigMap ==="
kubectl get configmap iqgeo-platform-configmap -n iqgeo -o yaml | grep -A 30 "data:"
echo ""

echo "=== 5. Init Container Status ==="
kubectl get pod $POD_NAME -n iqgeo -o jsonpath='{.status.initContainerStatuses}' | python3 -m json.tool 2>&1
echo ""

echo "=== 6. Init Container Logs (Last 50 lines) ==="
kubectl logs $POD_NAME -n iqgeo -c init-ensure-db-connection --tail=50 2>&1
echo ""

echo "=== 7. Main Container Status ==="
kubectl get pod $POD_NAME -n iqgeo -o jsonpath='{.status.containerStatuses}' | python3 -m json.tool 2>&1 || echo "Main container not started yet"
echo ""

echo "=== 8. Main Container Logs (if running) ==="
kubectl logs $POD_NAME -n iqgeo --tail=50 2>&1 || echo "Main container not started yet"
echo ""

echo "=== 9. Pod Events ==="
kubectl get events -n iqgeo --field-selector involvedObject.name=$POD_NAME --sort-by='.lastTimestamp' 2>&1 | tail -20
echo ""

echo "=== 10. Deployment Status ==="
kubectl get deployment iqgeo-platform -n iqgeo -o wide
echo ""

echo "=== 11. Service Status ==="
kubectl get svc -n iqgeo
echo ""

echo "=== 12. HPA Status ==="
kubectl get hpa -n iqgeo 2>&1
echo ""

echo "=== 13. Pod Description (Last 50 lines) ==="
kubectl describe pod $POD_NAME -n iqgeo | tail -50
echo ""

echo "========================================="
echo "SUMMARY"
echo "========================================="
echo ""

# Check PVC
PVC_STATUS=$(kubectl get pvc iqgeo-platform-shared-data -n iqgeo -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
echo "PVC Status: $PVC_STATUS"

# Check Pod Phase
POD_PHASE=$(kubectl get pod $POD_NAME -n iqgeo -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
echo "Pod Phase: $POD_PHASE"

# Check if pod is ready
POD_READY=$(kubectl get pod $POD_NAME -n iqgeo -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
echo "Pod Ready: $POD_READY"

# Check container statuses
INIT_STATE=$(kubectl get pod $POD_NAME -n iqgeo -o jsonpath='{.status.initContainerStatuses[0].state}' 2>/dev/null | python3 -c "import sys, json; s=json.load(sys.stdin); print(list(s.keys())[0] if s else 'unknown')" 2>/dev/null || echo "unknown")
echo "Init Container State: $INIT_STATE"

# Check if running
if [ "$POD_PHASE" = "Running" ] && [ "$POD_READY" = "True" ]; then
    echo ""
    echo "🎉 ✅ POD IS RUNNING AND READY!"
    echo ""
    echo "External access:"
    kubectl get svc iqgeo-platform -n iqgeo -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null && echo "" || echo "LoadBalancer IP not assigned yet"
elif [ "$INIT_STATE" = "running" ]; then
    echo ""
    echo "⏳ Init container is running (connecting to database)..."
    echo "   This is expected. Waiting for database connection to complete."
elif [ "$POD_PHASE" = "Pending" ]; then
    echo ""
    echo "⚠️  Pod is still Pending. Check events above for issues."
else
    echo ""
    echo "⚠️  Pod Status: $POD_PHASE (Init State: $INIT_STATE)"
fi

echo ""
echo "========================================="
echo "Check Complete - $(date)"
echo "========================================="

} > "$OUTPUT_FILE" 2>&1

echo "✅ Check complete! Output saved to: $OUTPUT_FILE"
echo ""
echo "To push results:"
echo "  git add $OUTPUT_FILE"
echo "  git commit -m \"Deployment check results\""
echo "  git push"
echo ""

# Show last 30 lines as preview
echo "Preview (last 30 lines):"
tail -30 "$OUTPUT_FILE"
