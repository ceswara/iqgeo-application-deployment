#!/bin/bash
# Check image pull error details
# Run this on your Kubernetes server

OUTPUT_FILE="image-pull-error.txt"

echo "=== Image Pull Error Check ===" > "$OUTPUT_FILE"
echo "Date: $(date)" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Get pod name
POD=$(kubectl get pods -n iqgeo -l app.kubernetes.io/name=iqgeo-platform -o name 2>/dev/null | head -1)

if [ -z "$POD" ]; then
    echo "No iqgeo-platform pod found" >> "$OUTPUT_FILE"
    exit 1
fi

echo "Pod: $POD" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Get pod status
echo "=== Pod Status ===" >> "$OUTPUT_FILE"
kubectl get $POD -n iqgeo >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

# Get pod events
echo "=== Pod Events ===" >> "$OUTPUT_FILE"
kubectl describe $POD -n iqgeo | grep -A 30 "Events:" >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

# Check image pull secrets
echo "=== Image Pull Secrets ===" >> "$OUTPUT_FILE"
kubectl get secret harbor-repository -n iqgeo >> "$OUTPUT_FILE" 2>&1 || echo "Secret not found" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Check init container image
echo "=== Init Container Image ===" >> "$OUTPUT_FILE"
kubectl get $POD -n iqgeo -o jsonpath='{.spec.initContainers[0].image}' >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Check main container image
echo "=== Main Container Image ===" >> "$OUTPUT_FILE"
kubectl get $POD -n iqgeo -o jsonpath='{.spec.containers[0].image}' >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Test Harbor connectivity
echo "=== Test Harbor Registry ===" >> "$OUTPUT_FILE"
echo "Testing: harbor.delivery.iqgeo.cloud" >> "$OUTPUT_FILE"
curl -s -o /dev/null -w "%{http_code}" https://harbor.delivery.iqgeo.cloud/api/v2.0/projects >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

echo "" >> "$OUTPUT_FILE"
echo "Output saved to: $OUTPUT_FILE"
