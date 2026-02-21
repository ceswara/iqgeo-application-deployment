#!/bin/bash
OUTPUT_FILE="db-config-check.txt"

echo "Checking database configuration..."
echo ""

{
echo "========================================="
echo "Database Configuration Check - $(date)"
echo "========================================="
echo ""

echo "=== 1. ConfigMap for IQGeo Platform ==="
kubectl get configmap iqgeo-platform-configmap -n iqgeo -o yaml 2>/dev/null || echo "ConfigMap not found"
echo ""

echo "=== 2. Database Environment Variables in Pod ==="
POD_NAME=$(kubectl get pods -n iqgeo -l app=iqgeo-platform --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}' 2>/dev/null)
echo "Pod: $POD_NAME"
echo ""

kubectl get pod $POD_NAME -n iqgeo -o jsonpath='{.spec.initContainers[0].env}' 2>/dev/null | python3 -m json.tool || echo "No env vars in init container"
echo ""

echo "=== 3. Init Container Command/Args ==="
kubectl get pod $POD_NAME -n iqgeo -o jsonpath='{.spec.initContainers[0]}' 2>/dev/null | python3 -m json.tool
echo ""

echo "=== 4. Helm Values (platform.database) ==="
helm get values iqgeo -n iqgeo -o yaml 2>/dev/null | grep -A 10 "database:" || echo "Helm values not available"
echo ""

echo "=== 5. Check if DB Host is Reachable from Cluster ==="
echo "Testing connectivity to 10.42.42.9:5432..."
kubectl run test-db-connection --image=busybox --rm -i --restart=Never -n iqgeo -- sh -c "nc -zv 10.42.42.9 5432 2>&1 || echo 'Connection failed'" 2>&1 | tail -5
echo ""

echo "=== 6. Full Pod Spec (Init Container) ==="
kubectl get pod $POD_NAME -n iqgeo -o yaml | grep -A 50 "initContainers:"
echo ""

echo "========================================="
echo "Check Complete - $(date)"
echo "========================================="

} > "$OUTPUT_FILE" 2>&1

echo "✅ Database configuration check saved to $OUTPUT_FILE"
echo ""
echo "Preview (last 30 lines):"
tail -30 "$OUTPUT_FILE"
