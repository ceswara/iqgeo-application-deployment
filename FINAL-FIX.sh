#!/bin/bash
# Complete fix: delete resources and recreate with correct values
# Run this on your Kubernetes server

set -e

OUTPUT_FILE="final-fix-output.txt"

echo "=========================================" > "$OUTPUT_FILE"
echo "IQGeo Final Fix - $(date)" >> "$OUTPUT_FILE"
echo "=========================================" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

cd "$(dirname "$0")"

echo "[$(date)] Step 1: Pulling latest config..." | tee -a "$OUTPUT_FILE"
git pull >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

echo "[$(date)] Step 2: Scaling deployment to 0..." | tee -a "$OUTPUT_FILE"
kubectl scale deployment iqgeo-platform -n iqgeo --replicas=0 >> "$OUTPUT_FILE" 2>&1
sleep 10
echo "" >> "$OUTPUT_FILE"

echo "[$(date)] Step 3: Deleting PVC with wrong access mode..." | tee -a "$OUTPUT_FILE"
kubectl delete pvc iqgeo-platform-shared-data -n iqgeo >> "$OUTPUT_FILE" 2>&1 || echo "PVC already gone" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "[$(date)] Step 4: Deleting HPA if exists..." | tee -a "$OUTPUT_FILE"
kubectl delete hpa iqgeo-platform-hpa -n iqgeo >> "$OUTPUT_FILE" 2>&1 || echo "HPA already gone" >> "$OUTPUT_FILE"
kubectl delete hpa iqgeo-platform--worker-hpa -n iqgeo >> "$OUTPUT_FILE" 2>&1 || echo "Worker HPA already gone" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "[$(date)] Step 5: Applying Terraform (recreating Helm release)..." | tee -a "$OUTPUT_FILE"
terraform apply -replace=helm_release.iqgeo -auto-approve >> "$OUTPUT_FILE" 2>&1
APPLY_STATUS=$?
if [ $APPLY_STATUS -eq 0 ]; then
    echo "[$(date)] ✅ Terraform apply completed" | tee -a "$OUTPUT_FILE"
else
    echo "[$(date)] ❌ Terraform apply failed with exit code $APPLY_STATUS" | tee -a "$OUTPUT_FILE"
    exit 1
fi
echo "" >> "$OUTPUT_FILE"

echo "[$(date)] Step 6: Waiting 45 seconds for deployment..." | tee -a "$OUTPUT_FILE"
sleep 45
echo "" >> "$OUTPUT_FILE"

echo "[$(date)] Step 7: Validation..." | tee -a "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "=== PVC Status ===" >> "$OUTPUT_FILE"
kubectl get pvc -n iqgeo >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

echo "=== PVC Access Mode ===" >> "$OUTPUT_FILE"
kubectl get pvc iqgeo-platform-shared-data -n iqgeo -o jsonpath='{.spec.accessModes}' >> "$OUTPUT_FILE" 2>&1 || echo "PVC not found" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "=== Deployment ===" >> "$OUTPUT_FILE"
kubectl get deployment iqgeo-platform -n iqgeo >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

echo "=== Pods ===" >> "$OUTPUT_FILE"
kubectl get pods -n iqgeo >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

echo "=== HPA Status ===" >> "$OUTPUT_FILE"
kubectl get hpa -n iqgeo >> "$OUTPUT_FILE" 2>&1 || echo "No HPAs" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Summary
PVC_STATUS=$(kubectl get pvc iqgeo-platform-shared-data -n iqgeo -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
PVC_ACCESS=$(kubectl get pvc iqgeo-platform-shared-data -n iqgeo -o jsonpath='{.spec.accessModes[0]}' 2>/dev/null || echo "NotFound")
REPLICAS=$(kubectl get deployment iqgeo-platform -n iqgeo -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
READY=$(kubectl get deployment iqgeo-platform -n iqgeo -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")

echo "=========================================" >> "$OUTPUT_FILE"
echo "FINAL STATUS" >> "$OUTPUT_FILE"
echo "=========================================" >> "$OUTPUT_FILE"
echo "PVC Status: $PVC_STATUS" >> "$OUTPUT_FILE"
echo "PVC Access Mode: $PVC_ACCESS" >> "$OUTPUT_FILE"
echo "Deployment Replicas: $REPLICAS" >> "$OUTPUT_FILE"
echo "Ready Replicas: $READY" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

if [ "$PVC_STATUS" = "Bound" ] && [ "$PVC_ACCESS" = "ReadWriteOnce" ] && [ "$REPLICAS" = "1" ]; then
    echo "✅ VALIDATION PASSED" | tee -a "$OUTPUT_FILE"
else
    echo "⚠️  Some issues remain (check above)" | tee -a "$OUTPUT_FILE"
fi

echo "" >> "$OUTPUT_FILE"
echo "Script completed at $(date)" >> "$OUTPUT_FILE"
echo "=========================================" >> "$OUTPUT_FILE"

echo ""
echo "Output saved to: $OUTPUT_FILE"
echo "Run: git add final-fix-output.txt && git commit -m 'Final fix complete' && git push"
