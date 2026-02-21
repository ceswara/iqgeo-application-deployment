#!/bin/bash
# Script to force-update Helm values with correct database credentials

set -e

echo "=========================================="
echo "Force Update Helm Values"
echo "=========================================="
echo ""

NAMESPACE="iqgeo"
RELEASE_NAME="iqgeo"
DB_PASSWORD="IQGeoXHKtCMFtrPRrjV012026!"  # ACTUAL working password (tested)
DB_USER="iqgeo"
DB_HOST="10.42.42.9"
DB_PORT="5432"
DB_NAME="iqgeo"

echo "Forcing Helm upgrade with correct database credentials..."
echo ""

# Use helm upgrade to force-set the database values
helm upgrade $RELEASE_NAME oci://harbor.delivery.iqgeo.cloud/helm/iqgeo-platform \
  --version 2.14.0 \
  --namespace $NAMESPACE \
  --reuse-values \
  --set platform.database.host=$DB_HOST \
  --set platform.database.port=$DB_PORT \
  --set platform.database.user=$DB_USER \
  --set platform.database.password=$DB_PASSWORD \
  --set platform.database.name=$DB_NAME \
  --set database.host=$DB_HOST \
  --set database.port=$DB_PORT \
  --set database.user=$DB_USER \
  --set database.password=$DB_PASSWORD \
  --set database.name=$DB_NAME \
  --wait \
  --timeout 5m

echo ""
echo "Helm upgrade complete!"
echo ""

# Wait for ConfigMap to update
echo "Waiting 5 seconds for ConfigMap to update..."
sleep 5
echo ""

# Verify ConfigMap
echo "Verifying ConfigMap credentials:"
kubectl get configmap -n $NAMESPACE -o yaml | grep -A1 "MYW_DB_USERNAME\|MYW_DB_PASSWORD\|PGUSER\|PGPASSWORD" | head -20
echo ""

echo "=========================================="
echo "Complete!"
echo "=========================================="
echo ""
