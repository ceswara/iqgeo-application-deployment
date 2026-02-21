#!/bin/bash
set -e

OUTPUT_FILE="pvc-fix-output.txt"

{
echo "========================================="
echo "Fixing Missing PVC Issue - $(date)"
echo "========================================="
echo ""

echo "Step 1: Check current PVC status..."
kubectl get pvc -n iqgeo
echo ""

echo "Step 2: Check if PVC is stuck in terminating state..."
PVC_STATUS=$(kubectl get pvc iqgeo-platform-shared-data -n iqgeo -o jsonpath='{.status.phase}' 2>&1 || echo "NotFound")
echo "PVC Status: $PVC_STATUS"
echo ""

if echo "$PVC_STATUS" | grep -q "NotFound"; then
    echo "PVC does not exist - checking if PV exists..."
    kubectl get pv | grep iqgeo-platform || echo "No PV found either"
    echo ""
    
    echo "Step 3: Checking Helm release for PVC configuration..."
    helm get values iqgeo -n iqgeo | grep -A 10 "persistence:" || echo "No persistence config in Helm values"
    echo ""
    
    echo "Step 4: Force Helm to recreate resources..."
    echo "Scaling deployment to 0 first..."
    kubectl scale deployment iqgeo-platform -n iqgeo --replicas=0
    sleep 5
    
    echo "Deleting the Helm release completely..."
    helm uninstall iqgeo -n iqgeo || echo "Already uninstalled"
    sleep 10
    
    echo "Step 5: Reapplying with Terraform..."
    cd /opt/iqgeo-application-deployment
    terraform apply -auto-approve
    
    echo ""
    echo "Step 6: Waiting 30 seconds for resources to be created..."
    sleep 30
    
    echo "Step 7: Checking PVC status..."
    kubectl get pvc -n iqgeo
    echo ""
    
    echo "Step 8: Checking pod status..."
    kubectl get pods -n iqgeo
    echo ""
    
else
    echo "PVC exists but may be stuck. Checking details..."
    kubectl describe pvc iqgeo-platform-shared-data -n iqgeo | tail -30
    echo ""
    
    # Check if finalizers are blocking deletion
    FINALIZERS=$(kubectl get pvc iqgeo-platform-shared-data -n iqgeo -o jsonpath='{.metadata.finalizers}' 2>/dev/null || echo "[]")
    if [ "$FINALIZERS" != "[]" ] && [ "$FINALIZERS" != "" ]; then
        echo "⚠️  PVC has finalizers blocking deletion: $FINALIZERS"
        echo "Removing finalizers to allow recreation..."
        kubectl patch pvc iqgeo-platform-shared-data -n iqgeo -p '{"metadata":{"finalizers":null}}' --type=merge
        sleep 5
        kubectl delete pvc iqgeo-platform-shared-data -n iqgeo --force --grace-period=0 2>/dev/null || echo "PVC already deleted"
        sleep 10
    fi
    
    echo "Reapplying with Terraform..."
    cd /opt/iqgeo-application-deployment
    terraform apply -replace=helm_release.iqgeo -auto-approve
    
    sleep 30
    kubectl get pvc -n iqgeo
    kubectl get pods -n iqgeo
fi

echo ""
echo "Step 9: Check storage class..."
kubectl get storageclass
echo ""

echo "Step 10: Check local-path-provisioner..."
kubectl get pods -n local-path-storage 2>/dev/null || echo "local-path-storage namespace not found"
echo ""

echo "========================================="
echo "Fix Complete - $(date)"
echo "========================================="

} > "$OUTPUT_FILE" 2>&1

cat "$OUTPUT_FILE"
echo ""
echo "✅ Output saved to $OUTPUT_FILE"
