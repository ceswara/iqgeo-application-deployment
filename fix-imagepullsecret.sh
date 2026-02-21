#!/bin/bash
set -e

echo "========================================="
echo "Fixing ImagePullSecret Configuration"
echo "========================================="

echo ""
echo "Current issue: Deployment uses 'harbor-registry-cred' but secret is 'harbor-repository'"
echo ""

echo "Step 1: Applying Terraform with updated imagePullSecrets configuration..."
terraform apply -replace=helm_release.iqgeo -auto-approve

echo ""
echo "Step 2: Waiting for rollout..."
sleep 10

echo ""
echo "Step 3: Checking deployment status..."
kubectl get deployment iqgeo-platform -n iqgeo
kubectl get pods -n iqgeo

echo ""
echo "Step 4: Verifying imagePullSecrets..."
kubectl get deployment iqgeo-platform -n iqgeo -o jsonpath='{.spec.template.spec.imagePullSecrets}' | jq '.'

echo ""
echo "========================================="
echo "Fix applied! Run ./deploy-and-validate.sh to verify"
echo "========================================="
