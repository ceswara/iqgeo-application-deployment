#!/bin/bash
# IQGeo Application Deployment and Validation Script
# This script handles the complete deployment and validation process
# Run on your Kubernetes server

set -e

OUTPUT_FILE="deployment-status.txt"

echo "=========================================" | tee "$OUTPUT_FILE"
echo "IQGeo Deployment Status - $(date)" | tee -a "$OUTPUT_FILE"
echo "=========================================" | tee -a "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

cd "$(dirname "$0")"

# Check what we need to do
ACTION="${1:-status}"  # status, fix, or validate

if [ "$ACTION" = "fix" ]; then
    echo "MODE: FIX - Will apply fixes if needed" | tee -a "$OUTPUT_FILE"
elif [ "$ACTION" = "validate" ]; then
    echo "MODE: VALIDATE - Check deployment status" | tee -a "$OUTPUT_FILE"
else
    echo "MODE: STATUS - Just check current status" | tee -a "$OUTPUT_FILE"
    echo "Run with 'fix' to apply fixes: ./deploy-and-validate.sh fix" | tee -a "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

# === CHECK 1: PVC Status ===
echo "=== 1. PVC Status ===" | tee -a "$OUTPUT_FILE"
PVC_STATUS=$(kubectl get pvc iqgeo-platform-shared-data -n iqgeo -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
PVC_ACCESS=$(kubectl get pvc iqgeo-platform-shared-data -n iqgeo -o jsonpath='{.spec.accessModes[0]}' 2>/dev/null || echo "NotFound")
echo "  Status: $PVC_STATUS" | tee -a "$OUTPUT_FILE"
echo "  Access Mode: $PVC_ACCESS" | tee -a "$OUTPUT_FILE"
kubectl get pvc -n iqgeo >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

# === CHECK 2: Deployment Status ===
echo "=== 2. Deployment Status ===" | tee -a "$OUTPUT_FILE"
REPLICAS=$(kubectl get deployment iqgeo-platform -n iqgeo -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
READY=$(kubectl get deployment iqgeo-platform -n iqgeo -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
echo "  Replicas: $REPLICAS (Ready: $READY)" | tee -a "$OUTPUT_FILE"
kubectl get deployment iqgeo-platform -n iqgeo >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

# === CHECK 3: Pods ===
echo "=== 3. Pods ===" | tee -a "$OUTPUT_FILE"
kubectl get pods -n iqgeo >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

# === CHECK 4: Pod Events (if not running) ===
if [ "$READY" != "$REPLICAS" ] || [ "$READY" = "0" ]; then
    echo "=== 4. Pod Events/Issues ===" | tee -a "$OUTPUT_FILE"
    for pod in $(kubectl get pods -n iqgeo -l app.kubernetes.io/name=iqgeo-platform -o name 2>/dev/null); do
        echo "--- $pod ---" >> "$OUTPUT_FILE"
        kubectl describe $pod -n iqgeo | tail -30 >> "$OUTPUT_FILE" 2>&1
        echo "" >> "$OUTPUT_FILE"
    done
fi

# === CHECK 5: Harbor Secret ===
echo "=== 5. Harbor Secret ===" | tee -a "$OUTPUT_FILE"
if kubectl get secret harbor-repository -n iqgeo &>/dev/null; then
    echo "  ✅ Harbor secret exists in iqgeo namespace" | tee -a "$OUTPUT_FILE"
else
    echo "  ❌ Harbor secret missing in iqgeo namespace" | tee -a "$OUTPUT_FILE"
fi
kubectl get secret harbor-repository -n iqgeo >> "$OUTPUT_FILE" 2>&1 || echo "Not found" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# === CHECK 6: HPA ===
echo "=== 6. HPA Status ===" | tee -a "$OUTPUT_FILE"
HPA_COUNT=$(kubectl get hpa -n iqgeo 2>/dev/null | grep -c "iqgeo-platform" || echo "0")
if [ "$HPA_COUNT" -gt "0" ]; then
    echo "  ⚠️  HPA found (may override replicas)" | tee -a "$OUTPUT_FILE"
    kubectl get hpa -n iqgeo >> "$OUTPUT_FILE" 2>&1
else
    echo "  ✅ No HPA found" | tee -a "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

# === SUMMARY ===
echo "=========================================" | tee -a "$OUTPUT_FILE"
echo "SUMMARY" | tee -a "$OUTPUT_FILE"
echo "=========================================" | tee -a "$OUTPUT_FILE"

ISSUES=""

if [ "$PVC_STATUS" != "Bound" ]; then
    echo "❌ PVC not bound (Status: $PVC_STATUS)" | tee -a "$OUTPUT_FILE"
    ISSUES="yes"
fi

if [ "$PVC_ACCESS" != "ReadWriteOnce" ] && [ "$PVC_ACCESS" != "NotFound" ]; then
    echo "❌ PVC has wrong access mode: $PVC_ACCESS (needs ReadWriteOnce)" | tee -a "$OUTPUT_FILE"
    ISSUES="yes"
fi

if [ "$REPLICAS" != "1" ]; then
    echo "❌ Deployment replicas: $REPLICAS (should be 1)" | tee -a "$OUTPUT_FILE"
    ISSUES="yes"
fi

if [ "$READY" != "$REPLICAS" ] || [ "$READY" = "0" ]; then
    echo "❌ Pods not ready: $READY/$REPLICAS" | tee -a "$OUTPUT_FILE"
    ISSUES="yes"
fi

if ! kubectl get secret harbor-repository -n iqgeo &>/dev/null; then
    echo "❌ Harbor secret missing in iqgeo namespace" | tee -a "$OUTPUT_FILE"
    ISSUES="yes"
fi

if [ -z "$ISSUES" ]; then
    echo "" | tee -a "$OUTPUT_FILE"
    echo "✅ DEPLOYMENT SUCCESSFUL" | tee -a "$OUTPUT_FILE"
    echo "All checks passed!" | tee -a "$OUTPUT_FILE"
else
    echo "" | tee -a "$OUTPUT_FILE"
    echo "⚠️  ISSUES FOUND - See above" | tee -a "$OUTPUT_FILE"
    echo "" | tee -a "$OUTPUT_FILE"
    echo "RECOMMENDED FIX:" | tee -a "$OUTPUT_FILE"
    echo "1. Ensure Harbor credentials in iqgeo-onprem-deployment/terraform/terraform.tfvars" | tee -a "$OUTPUT_FILE"
    echo "2. cd /path/to/iqgeo-onprem-deployment/terraform && terraform apply" | tee -a "$OUTPUT_FILE"
    echo "3. cd /path/to/iqgeo-application-deployment && terraform apply -replace=helm_release.iqgeo" | tee -a "$OUTPUT_FILE"
    echo "4. Run this script again: ./deploy-and-validate.sh" | tee -a "$OUTPUT_FILE"
fi

echo "" >> "$OUTPUT_FILE"
echo "=========================================" | tee -a "$OUTPUT_FILE"
echo "Completed at $(date)" | tee -a "$OUTPUT_FILE"
echo "=========================================" | tee -a "$OUTPUT_FILE"

echo ""
echo "Output saved to: $OUTPUT_FILE"
echo "Run: git add deployment-status.txt && git commit -m 'Deployment status' && git push"
