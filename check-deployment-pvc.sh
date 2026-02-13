#!/bin/bash
# Script to check deployment spec and PVC status
# Run this on your Kubernetes server

OUTPUT_FILE="deployment-pvc-check.txt"

echo "=== Deployment and PVC Check ===" > "$OUTPUT_FILE"
echo "Date: $(date)" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Check deployment spec resources
echo "=== Deployment Spec Resources ===" >> "$OUTPUT_FILE"
kubectl get deployment iqgeo-platform -n iqgeo -o jsonpath='{.spec.template.spec.containers[0].resources}' >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Check PVC status
echo "=== PVC Status ===" >> "$OUTPUT_FILE"
kubectl get pvc -n iqgeo >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

# Check PVC details
echo "=== PVC Details ===" >> "$OUTPUT_FILE"
kubectl describe pvc iqgeo-platform-shared-data -n iqgeo >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

# Check StorageClass
echo "=== StorageClass Status ===" >> "$OUTPUT_FILE"
kubectl get sc efs -o yaml >> "$OUTPUT_FILE" 2>&1 || echo "StorageClass 'efs' not found" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Check PV status
echo "=== PV Status ===" >> "$OUTPUT_FILE"
kubectl get pv >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

# Check pod events for volume binding errors
echo "=== Pod Events (Volume Binding) ===" >> "$OUTPUT_FILE"
for pod in $(kubectl get pods -n iqgeo -l app.kubernetes.io/name=iqgeo-platform -o name 2>/dev/null); do
    echo "--- $pod ---" >> "$OUTPUT_FILE"
    kubectl describe $pod -n iqgeo | grep -A 20 "Events:" >> "$OUTPUT_FILE" 2>&1
    echo "" >> "$OUTPUT_FILE"
done

# Check if local-path provisioner is running
echo "=== Local Path Provisioner Status ===" >> "$OUTPUT_FILE"
kubectl get pods -n local-path-storage >> "$OUTPUT_FILE" 2>&1 || echo "local-path-storage namespace not found" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "Output saved to: $OUTPUT_FILE"
echo "Please git add, commit, and push this file."
