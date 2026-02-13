#!/bin/bash
# Script to check what Helm values were actually applied

OUTPUT_FILE="helm-values-check.txt"

echo "=== Checking Helm Release Values ===" > "$OUTPUT_FILE"
echo "Date: $(date)" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Check Helm values
echo "=== Helm Get Values ===" >> "$OUTPUT_FILE"
helm get values iqgeo -n iqgeo >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

# Check Helm manifest for deployment
echo "=== Helm Manifest (Deployment section) ===" >> "$OUTPUT_FILE"
helm get manifest iqgeo -n iqgeo | grep -A 50 "kind: Deployment" >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

# Check actual deployment spec
echo "=== Actual Deployment Spec ===" >> "$OUTPUT_FILE"
kubectl get deployment iqgeo-platform -n iqgeo -o yaml | grep -A 5 "replicas:" >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

# Check pod resource requests
echo "=== Pod Resource Requests ===" >> "$OUTPUT_FILE"
kubectl get pod -n iqgeo -l app.kubernetes.io/name=iqgeo-platform -o jsonpath='{.items[0].spec.containers[0].resources}' 2>/dev/null | jq . >> "$OUTPUT_FILE" 2>&1 || echo "No pods found or jq not installed" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "Output saved to: $OUTPUT_FILE"
