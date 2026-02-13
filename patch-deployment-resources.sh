#!/bin/bash
# Script to patch deployment with correct resource values
# Run this on your Kubernetes server

set -e

OUTPUT_FILE="patch-deployment-output.txt"

echo "=== Patch Deployment Resources ===" > "$OUTPUT_FILE"
echo "Date: $(date)" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Check current resources
echo "=== Current Pod Resources ===" >> "$OUTPUT_FILE"
kubectl get pod -n iqgeo -l app.kubernetes.io/name=iqgeo-platform -o jsonpath='{.items[0].spec.containers[0].resources}' >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

# Patch deployment with correct resources
echo "=== Patching Deployment Resources ===" >> "$OUTPUT_FILE"
kubectl patch deployment iqgeo-platform -n iqgeo -p '{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "iqgeo-platform",
          "resources": {
            "limits": {
              "cpu": "1",
              "memory": "1Gi"
            },
            "requests": {
              "cpu": "500m",
              "memory": "512Mi"
            }
          }
        }]
      }
    }
  }
}' >> "$OUTPUT_FILE" 2>&1

echo "Deployment patched" | tee -a "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Wait for rollout
echo "Waiting 20 seconds for rollout..." | tee -a "$OUTPUT_FILE"
sleep 20
echo "" >> "$OUTPUT_FILE"

# Check new pod resources
echo "=== New Pod Resources ===" >> "$OUTPUT_FILE"
kubectl get pod -n iqgeo -l app.kubernetes.io/name=iqgeo-platform -o jsonpath='{.items[0].spec.containers[0].resources}' >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

# Check pod status
echo "=== Pod Status ===" >> "$OUTPUT_FILE"
kubectl get pods -n iqgeo -l app.kubernetes.io/name=iqgeo-platform >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

# Check pod events
echo "=== Pod Events ===" >> "$OUTPUT_FILE"
for pod in $(kubectl get pods -n iqgeo -l app.kubernetes.io/name=iqgeo-platform -o name 2>/dev/null); do
    echo "--- $pod ---" >> "$OUTPUT_FILE"
    kubectl describe $pod -n iqgeo | grep -A 10 "Events:" >> "$OUTPUT_FILE" 2>&1
    echo "" >> "$OUTPUT_FILE"
done

echo "Output saved to: $OUTPUT_FILE"
echo "Please git add, commit, and push this file."
