#!/bin/bash
# Script to scale deployment to 1 replica after HPA deletion
# Run this on your Kubernetes server

set -e

OUTPUT_FILE="scale-deployment-output.txt"

echo "=== Scale Deployment Script ===" > "$OUTPUT_FILE"
echo "Date: $(date)" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Check current state
echo "=== Current Deployment State ===" >> "$OUTPUT_FILE"
kubectl get deployment iqgeo-platform -n iqgeo >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

# Check current replica count
CURRENT_REPLICAS=$(kubectl get deployment iqgeo-platform -n iqgeo -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "unknown")
echo "Current replicas: $CURRENT_REPLICAS" | tee -a "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Scale down to 1 replica
echo "=== Scaling deployment to 1 replica ===" >> "$OUTPUT_FILE"
kubectl scale deployment iqgeo-platform -n iqgeo --replicas=1 >> "$OUTPUT_FILE" 2>&1
echo "Scaled deployment to 1 replica" | tee -a "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Wait a bit for Kubernetes to process
echo "Waiting 15 seconds for Kubernetes to process..." | tee -a "$OUTPUT_FILE"
sleep 15
echo "" >> "$OUTPUT_FILE"

# Verify scaling
echo "=== Deployment State After Scaling ===" >> "$OUTPUT_FILE"
kubectl get deployment iqgeo-platform -n iqgeo >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

# Check replica count
NEW_REPLICAS=$(kubectl get deployment iqgeo-platform -n iqgeo -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "unknown")
echo "New replicas: $NEW_REPLICAS" | tee -a "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Check pods
echo "=== Pod Status ===" >> "$OUTPUT_FILE"
kubectl get pods -n iqgeo -l app.kubernetes.io/name=iqgeo-platform >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

# Count running vs pending
RUNNING=$(kubectl get pods -n iqgeo -l app.kubernetes.io/name=iqgeo-platform --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')
PENDING=$(kubectl get pods -n iqgeo -l app.kubernetes.io/name=iqgeo-platform --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l | tr -d ' ')

echo "=== Summary ===" >> "$OUTPUT_FILE"
echo "Deployment replicas: $NEW_REPLICAS" >> "$OUTPUT_FILE"
echo "Running pods: $RUNNING" >> "$OUTPUT_FILE"
echo "Pending pods: $PENDING" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

if [ "$NEW_REPLICAS" = "1" ]; then
    echo "✅ Successfully scaled to 1 replica" | tee -a "$OUTPUT_FILE"
else
    echo "⚠️  Warning: Replicas still show as $NEW_REPLICAS" | tee -a "$OUTPUT_FILE"
fi

echo "" >> "$OUTPUT_FILE"
echo "Output saved to: $OUTPUT_FILE"
echo "Please git add, commit, and push this file."
