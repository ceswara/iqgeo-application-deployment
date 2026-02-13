#!/bin/bash
# Script to check and delete HPA if it exists
# Run this on your Kubernetes server

set -e

OUTPUT_FILE="hpa-deletion-output.txt"

echo "=== HPA Deletion Script ===" > "$OUTPUT_FILE"
echo "Date: $(date)" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Check if HPA exists
echo "=== Checking for HPA resources ===" >> "$OUTPUT_FILE"
kubectl get hpa -n iqgeo >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

# List all HPAs
echo "=== All HPAs in iqgeo namespace ===" >> "$OUTPUT_FILE"
kubectl get hpa -n iqgeo -o yaml >> "$OUTPUT_FILE" 2>&1 || echo "No HPAs found" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Delete HPAs that target iqgeo-platform deployment
echo "=== Deleting HPAs for iqgeo-platform ===" >> "$OUTPUT_FILE"
for hpa in $(kubectl get hpa -n iqgeo -o jsonpath='{.items[?(@.spec.scaleTargetRef.name=="iqgeo-platform")].metadata.name}' 2>/dev/null); do
    echo "Deleting HPA: $hpa" | tee -a "$OUTPUT_FILE"
    kubectl delete hpa "$hpa" -n iqgeo >> "$OUTPUT_FILE" 2>&1
done

# Also try deleting by common names
for hpa_name in "iqgeo-platform" "iqgeo-platform-hpa" "iqgeo-platform--hpa"; do
    if kubectl get hpa "$hpa_name" -n iqgeo &>/dev/null; then
        echo "Deleting HPA: $hpa_name" | tee -a "$OUTPUT_FILE"
        kubectl delete hpa "$hpa_name" -n iqgeo >> "$OUTPUT_FILE" 2>&1
    fi
done

echo "" >> "$OUTPUT_FILE"
echo "=== Verifying HPA deletion ===" >> "$OUTPUT_FILE"
kubectl get hpa -n iqgeo >> "$OUTPUT_FILE" 2>&1 || echo "No HPAs remaining" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Check deployment replicas after HPA deletion
echo "=== Deployment status after HPA deletion ===" >> "$OUTPUT_FILE"
kubectl get deployment iqgeo-platform -n iqgeo >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

# Wait a bit for Kubernetes to reconcile
echo "Waiting 10 seconds for Kubernetes to reconcile..." | tee -a "$OUTPUT_FILE"
sleep 10

echo "=== Final deployment status ===" >> "$OUTPUT_FILE"
kubectl get deployment iqgeo-platform -n iqgeo -o jsonpath='{.spec.replicas}' >> "$OUTPUT_FILE" 2>&1 && echo "" >> "$OUTPUT_FILE"
kubectl get pods -n iqgeo -l app.kubernetes.io/name=iqgeo-platform >> "$OUTPUT_FILE" 2>&1

echo "" >> "$OUTPUT_FILE"
echo "Output saved to: $OUTPUT_FILE"
echo "Please git add, commit, and push this file."
