#!/bin/bash
OUTPUT_FILE="pod-diagnosis.txt"

echo "Running pod diagnosis and saving to $OUTPUT_FILE..."
echo ""

{
echo "========================================="
echo "Pod Diagnosis - $(date)"
echo "========================================="
echo ""

POD_NAME=$(kubectl get pods -n iqgeo -l app=iqgeo-platform --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}' 2>/dev/null)

if [ -z "$POD_NAME" ]; then
    echo "❌ No pod found with label app=iqgeo-platform"
    exit 1
fi

echo "Pod Name: $POD_NAME"
echo ""

echo "=== 1. Current Pod Status ==="
kubectl get pods -n iqgeo
echo ""

echo "=== 2. Pod Details ==="
kubectl get pod $POD_NAME -n iqgeo -o wide
echo ""

echo "=== 3. Pod Phase ==="
kubectl get pod $POD_NAME -n iqgeo -o jsonpath='{.status.phase}'
echo ""
echo ""

echo "=== 4. Init Container Status ==="
kubectl get pod $POD_NAME -n iqgeo -o jsonpath='{.status.initContainerStatuses}' 2>/dev/null | python3 -m json.tool || echo "No init container status available"
echo ""

echo "=== 5. Container Statuses ==="
kubectl get pod $POD_NAME -n iqgeo -o jsonpath='{.status.containerStatuses}' 2>/dev/null | python3 -m json.tool || echo "No container status available"
echo ""

echo "=== 6. Recent Pod Events ==="
kubectl get events -n iqgeo --field-selector involvedObject.name=$POD_NAME --sort-by='.lastTimestamp' 2>/dev/null
echo ""

echo "=== 7. Pod Description (Last 60 Lines) ==="
kubectl describe pod $POD_NAME -n iqgeo | tail -60
echo ""

echo "=== 8. Init Container Logs ==="
kubectl logs $POD_NAME -n iqgeo -c init-ensure-db-connection --tail=100 2>&1 || echo "Init container logs not available yet (container may not have started)"
echo ""

echo "=== 9. Main Container Logs ==="
kubectl logs $POD_NAME -n iqgeo --tail=100 2>&1 || echo "Main container logs not available yet (container may not have started)"
echo ""

echo "=== 10. All Pods in Namespace ==="
kubectl get pods -n iqgeo -o wide
echo ""

echo "=== 11. Harbor Secret Check ==="
kubectl get secret harbor-repository -n iqgeo -o jsonpath='{.data.\.dockerconfigjson}' 2>/dev/null | base64 -d | python3 -m json.tool || echo "Harbor secret not found"
echo ""

echo "========================================="
echo "Diagnosis Complete - $(date)"
echo "========================================="

} > "$OUTPUT_FILE" 2>&1

echo "✅ Diagnosis saved to $OUTPUT_FILE"
echo ""
echo "Preview (last 30 lines):"
tail -30 "$OUTPUT_FILE"
