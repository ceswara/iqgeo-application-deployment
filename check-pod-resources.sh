#!/bin/bash
# Script to check pod resource requests and limits
# Run this on your Kubernetes server

OUTPUT_FILE="pod-resources-check.txt"

echo "=== Pod Resources Check ===" > "$OUTPUT_FILE"
echo "Date: $(date)" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Check deployment spec
echo "=== Deployment Spec (replicas and resources) ===" >> "$OUTPUT_FILE"
kubectl get deployment iqgeo-platform -n iqgeo -o yaml | grep -A 20 "spec:" | head -30 >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

# Check pod resource requests
echo "=== Pod Resource Requests and Limits ===" >> "$OUTPUT_FILE"
for pod in $(kubectl get pods -n iqgeo -l app.kubernetes.io/name=iqgeo-platform -o name 2>/dev/null); do
    echo "--- $pod ---" >> "$OUTPUT_FILE"
    kubectl get $pod -n iqgeo -o jsonpath='{.spec.containers[0].resources}' >> "$OUTPUT_FILE" 2>&1
    echo "" >> "$OUTPUT_FILE"
done

# Check pod status and events
echo "=== Pod Status and Events ===" >> "$OUTPUT_FILE"
kubectl get pods -n iqgeo -l app.kubernetes.io/name=iqgeo-platform >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

for pod in $(kubectl get pods -n iqgeo -l app.kubernetes.io/name=iqgeo-platform -o name 2>/dev/null); do
    echo "--- Events for $pod ---" >> "$OUTPUT_FILE"
    kubectl describe $pod -n iqgeo | grep -A 10 "Events:" >> "$OUTPUT_FILE" 2>&1
    echo "" >> "$OUTPUT_FILE"
done

# Check node resources
echo "=== Node Resources (available memory) ===" >> "$OUTPUT_FILE"
kubectl top nodes 2>/dev/null >> "$OUTPUT_FILE" || echo "Metrics server not available" >> "$OUTPUT_FILE"
kubectl get nodes -o custom-columns=NAME:.metadata.name,CPU:.status.capacity.cpu,MEMORY:.status.capacity.memory >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

echo "Output saved to: $OUTPUT_FILE"
echo "Please git add, commit, and push this file."
