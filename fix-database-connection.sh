#!/bin/bash
set -e

echo "========================================="
echo "Fixing Database Connection Configuration"
echo "========================================="
echo ""

echo "Issue: Init container cannot connect to database (missing hostname)"
echo "Fix: Force database configuration via Helm --set"
echo ""

echo "Step 1: Delete current pod to stop failing init container..."
kubectl delete pod -n iqgeo -l app=iqgeo-platform
echo "✅ Pod deleted"
echo ""

echo "Step 2: Applying Terraform with forced database configuration..."
terraform apply -replace=helm_release.iqgeo -auto-approve

echo ""
echo "Step 3: Waiting 30 seconds for new pod to start..."
sleep 30

echo ""
echo "Step 4: Checking pod status..."
kubectl get pods -n iqgeo
echo ""

echo "Step 5: Checking init container logs..."
POD_NAME=$(kubectl get pods -n iqgeo -l app=iqgeo-platform --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}' 2>/dev/null)
echo "Pod: $POD_NAME"
echo ""
kubectl logs $POD_NAME -n iqgeo -c init-ensure-db-connection --tail=20 2>&1 || echo "Waiting for init container to start..."

echo ""
echo "========================================="
echo "Fix Applied!"
echo "========================================="
echo ""
echo "Monitor with: kubectl get pods -n iqgeo -w"
echo "Check logs:   kubectl logs -f $POD_NAME -n iqgeo -c init-ensure-db-connection"
echo ""
echo "Run full validation:"
echo "  ./deploy-and-validate.sh"
echo ""
