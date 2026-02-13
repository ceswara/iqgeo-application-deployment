#!/bin/bash
# Script to fix replica count issue and export results
# Run this on the server where Terraform is installed

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_FILE="${SCRIPT_DIR}/terraform-fix-output.txt"

echo "=========================================" > "$OUTPUT_FILE"
echo "Terraform Fix Replicas - $(date)" >> "$OUTPUT_FILE"
echo "=========================================" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

cd "$SCRIPT_DIR"

echo "[$(date)] Starting fix process..." | tee -a "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Step 1: Check current Terraform state
echo "=== STEP 1: Current Terraform State ===" | tee -a "$OUTPUT_FILE"
terraform show | head -50 >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

# Step 2: Check current deployment state
echo "=== STEP 2: Current Kubernetes Deployment State ===" | tee -a "$OUTPUT_FILE"
kubectl get deployment iqgeo-platform -n iqgeo -o yaml >> "$OUTPUT_FILE" 2>&1 || echo "Deployment not found or error" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "=== Current Pods ===" | tee -a "$OUTPUT_FILE"
kubectl get pods -n iqgeo >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

# Step 3: Check terraform.tfvars replica_count value
echo "=== STEP 3: Checking terraform.tfvars ===" | tee -a "$OUTPUT_FILE"
if grep -q "replica_count" terraform.tfvars; then
    grep "replica_count" terraform.tfvars >> "$OUTPUT_FILE"
else
    echo "replica_count not found in terraform.tfvars" >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

# Step 4: Run terraform plan to see what will change
echo "=== STEP 4: Terraform Plan (before fix) ===" | tee -a "$OUTPUT_FILE"
terraform plan -replace=helm_release.iqgeo >> "$OUTPUT_FILE" 2>&1 || echo "Plan failed or no changes" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Step 5: Apply the fix
echo "=== STEP 5: Applying Terraform Fix ===" | tee -a "$OUTPUT_FILE"
echo "[$(date)] Running: terraform apply -replace=helm_release.iqgeo" | tee -a "$OUTPUT_FILE"
echo "Note: Using set_values to force override replicaCount and resources" | tee -a "$OUTPUT_FILE"
terraform apply -replace=helm_release.iqgeo -auto-approve >> "$OUTPUT_FILE" 2>&1
APPLY_EXIT_CODE=$?
echo "" >> "$OUTPUT_FILE"

if [ $APPLY_EXIT_CODE -eq 0 ]; then
    echo "[$(date)] ✅ Terraform apply completed successfully" | tee -a "$OUTPUT_FILE"
else
    echo "[$(date)] ❌ Terraform apply failed with exit code: $APPLY_EXIT_CODE" | tee -a "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

# Step 6: Wait a bit for Kubernetes to process
echo "[$(date)] Waiting 30 seconds for Kubernetes to process changes..." | tee -a "$OUTPUT_FILE"
sleep 30
echo "" >> "$OUTPUT_FILE"

# Step 7: Check deployment after fix
echo "=== STEP 6: Deployment State After Fix ===" | tee -a "$OUTPUT_FILE"
kubectl get deployment iqgeo-platform -n iqgeo >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

echo "=== Pods After Fix ===" | tee -a "$OUTPUT_FILE"
kubectl get pods -n iqgeo >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

# Step 8: Check pod events/status
echo "=== STEP 7: Pod Details ===" | tee -a "$OUTPUT_FILE"
for pod in $(kubectl get pods -n iqgeo -l app.kubernetes.io/name=iqgeo-platform -o name 2>/dev/null | head -3); do
    echo "--- $pod ---" >> "$OUTPUT_FILE"
    kubectl describe $pod -n iqgeo >> "$OUTPUT_FILE" 2>&1 || true
    echo "" >> "$OUTPUT_FILE"
done

# Step 9: Check PVC status
echo "=== STEP 8: PVC Status ===" | tee -a "$OUTPUT_FILE"
kubectl get pvc -n iqgeo >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

# Step 10: Summary
echo "=== SUMMARY ===" | tee -a "$OUTPUT_FILE"
echo "[$(date)] Fix process completed" | tee -a "$OUTPUT_FILE"
echo "Check terraform-fix-output.txt for full details" | tee -a "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Final status
echo "=== FINAL STATUS ===" | tee -a "$OUTPUT_FILE"
echo "Deployment replicas:" | tee -a "$OUTPUT_FILE"
kubectl get deployment iqgeo-platform -n iqgeo -o jsonpath='{.spec.replicas}' >> "$OUTPUT_FILE" 2>&1 && echo "" >> "$OUTPUT_FILE"
echo "Running pods:" | tee -a "$OUTPUT_FILE"
kubectl get pods -n iqgeo -l app.kubernetes.io/name=iqgeo-platform --field-selector=status.phase=Running --no-headers | wc -l >> "$OUTPUT_FILE" 2>&1
echo "Pending pods:" | tee -a "$OUTPUT_FILE"
kubectl get pods -n iqgeo -l app.kubernetes.io/name=iqgeo-platform --field-selector=status.phase=Pending --no-headers | wc -l >> "$OUTPUT_FILE" 2>&1

echo "" >> "$OUTPUT_FILE"
echo "=========================================" >> "$OUTPUT_FILE"
echo "Script completed at $(date)" >> "$OUTPUT_FILE"
echo "=========================================" >> "$OUTPUT_FILE"

echo ""
echo "✅ Script completed! Output saved to: $OUTPUT_FILE"
echo "Please git add, commit, and push this file so we can review the results."
