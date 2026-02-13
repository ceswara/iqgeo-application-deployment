#!/bin/bash
# Validation script - run after terraform apply
# Run on your Kubernetes server, then push validate-output.txt

set -e

OUTPUT_FILE="validate-output.txt"

echo "=========================================" > "$OUTPUT_FILE"
echo "IQGeo Deployment Validation - $(date)" >> "$OUTPUT_FILE"
echo "=========================================" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# 1. PVC status
echo "=== 1. PVC Status ===" >> "$OUTPUT_FILE"
kubectl get pvc -n iqgeo >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

# 2. PVC details (access mode)
echo "=== 2. PVC Details (access mode) ===" >> "$OUTPUT_FILE"
kubectl get pvc iqgeo-platform-shared-data -n iqgeo -o jsonpath='{.spec.accessModes}' 2>/dev/null >> "$OUTPUT_FILE" || echo "PVC not found" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# 3. Deployment status
echo "=== 3. Deployment Status ===" >> "$OUTPUT_FILE"
kubectl get deployment iqgeo-platform -n iqgeo >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

# 4. Replica count
echo "=== 4. Replica Count ===" >> "$OUTPUT_FILE"
kubectl get deployment iqgeo-platform -n iqgeo -o jsonpath='{.spec.replicas}' >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# 5. Pod status
echo "=== 5. Pod Status (iqgeo namespace) ===" >> "$OUTPUT_FILE"
kubectl get pods -n iqgeo >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

# 6. iqgeo-platform pod details
echo "=== 6. iqgeo-platform Pod Details ===" >> "$OUTPUT_FILE"
for pod in $(kubectl get pods -n iqgeo -l app.kubernetes.io/name=iqgeo-platform -o name 2>/dev/null); do
    echo "--- $pod ---" >> "$OUTPUT_FILE"
    kubectl get $pod -n iqgeo -o wide >> "$OUTPUT_FILE" 2>&1
    kubectl describe $pod -n iqgeo | grep -A 15 "Events:" >> "$OUTPUT_FILE" 2>&1
    echo "" >> "$OUTPUT_FILE"
done

# 7. Helm release status
echo "=== 7. Helm Release Status ===" >> "$OUTPUT_FILE"
helm list -n iqgeo >> "$OUTPUT_FILE" 2>&1 || echo "helm not in PATH or error" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# 8. Services
echo "=== 8. Services ===" >> "$OUTPUT_FILE"
kubectl get svc -n iqgeo >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

# 9. Summary / validation result
echo "=== 9. Validation Summary ===" >> "$OUTPUT_FILE"
PVC_STATUS=$(kubectl get pvc iqgeo-platform-shared-data -n iqgeo -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
DEPLOY_READY=$(kubectl get deployment iqgeo-platform -n iqgeo -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
DEPLOY_DESIRED=$(kubectl get deployment iqgeo-platform -n iqgeo -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")

echo "PVC phase: $PVC_STATUS" >> "$OUTPUT_FILE"
echo "Deployment ready/desired: $DEPLOY_READY / $DEPLOY_DESIRED" >> "$OUTPUT_FILE"

if [ "$PVC_STATUS" = "Bound" ] && [ "$DEPLOY_READY" = "$DEPLOY_DESIRED" ] && [ "$DEPLOY_DESIRED" != "0" ]; then
    echo "Result: VALIDATION PASSED" >> "$OUTPUT_FILE"
else
    echo "Result: VALIDATION INCOMPLETE (check sections above)" >> "$OUTPUT_FILE"
fi

echo "" >> "$OUTPUT_FILE"
echo "=========================================" >> "$OUTPUT_FILE"
echo "End of validation" >> "$OUTPUT_FILE"
echo "=========================================" >> "$OUTPUT_FILE"

echo "Output saved to: $OUTPUT_FILE"
echo "Run: git add validate-output.txt && git commit -m 'Validation after terraform apply' && git push"
