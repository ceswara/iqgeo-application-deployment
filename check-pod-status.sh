#!/bin/bash
# Quick pod status check
# Run this on your Kubernetes server

OUTPUT_FILE="pod-status.txt"

echo "=== Pod Status Check ===" > "$OUTPUT_FILE"
echo "Date: $(date)" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "=== All Pods in iqgeo namespace ===" >> "$OUTPUT_FILE"
kubectl get pods -n iqgeo >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

echo "=== iqgeo-platform Pod Details ===" >> "$OUTPUT_FILE"
POD=$(kubectl get pods -n iqgeo -l app.kubernetes.io/name=iqgeo-platform -o name 2>/dev/null | head -1)
if [ -n "$POD" ]; then
    kubectl describe $POD -n iqgeo >> "$OUTPUT_FILE" 2>&1
else
    echo "No iqgeo-platform pod found" >> "$OUTPUT_FILE"
fi

echo "" >> "$OUTPUT_FILE"
echo "Output saved to: $OUTPUT_FILE"
