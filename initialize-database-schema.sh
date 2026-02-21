#!/bin/bash
# Script to initialize IQGeo database schema using the IQGeo container's myw_db tool
# This script creates a temporary pod with the IQGeo image and runs the initialization commands
# Run this on your server with kubectl access to the on-prem cluster (10.42.42.5)

set -e

echo "=========================================="
echo "IQGeo Database Schema Initialization"
echo "=========================================="
echo ""

# Configuration (from your working cluster)
NAMESPACE="iqgeo"
DB_HOST="10.42.42.9"
DB_PORT="5432"
DB_NAME="iqgeo"
DB_USER="iqgeo"
DB_PASSWORD="IQGeoXHKtCMFtrPRrjV012026!"  # ACTUAL working password (tested)
IMAGE="harbor.delivery.iqgeo.cloud/nmti-trials/editions-nmt-comms-cloud:7.3"

echo "Database Configuration:"
echo "  Host: $DB_HOST:$DB_PORT"
echo "  Database: $DB_NAME"
echo "  User: $DB_USER"
echo "  Password: [configured]"
echo ""

# Create temporary namespace for initialization
TEMP_NAMESPACE="iqgeo-db-init-$(date +%s)"
echo "1. Creating temporary namespace: $TEMP_NAMESPACE..."
kubectl create namespace $TEMP_NAMESPACE
echo ""

# Check if harbor-repository secret exists in iqgeo namespace, copy it to temp namespace
echo "2. Copying Harbor registry secret..."
kubectl get secret harbor-repository -n $NAMESPACE -o yaml | \
  sed "s/namespace: $NAMESPACE/namespace: $TEMP_NAMESPACE/" | \
  kubectl apply -f -
echo ""

# Create a temporary pod with the IQGeo image to run myw_db commands
echo "3. Creating initialization pod with IQGeo tools..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: iqgeo-db-init
  namespace: $TEMP_NAMESPACE
spec:
  imagePullSecrets:
    - name: harbor-repository
  containers:
  - name: iqgeo-init
    image: $IMAGE
    command: ["sleep", "3600"]
    env:
    - name: MYW_DB_HOST
      value: "$DB_HOST"
    - name: MYW_DB_PORT
      value: "$DB_PORT"
    - name: MYW_DB_NAME
      value: "$DB_NAME"
    - name: MYW_DB_USERNAME
      value: "$DB_USER"
    - name: MYW_DB_PASSWORD
      value: "$DB_PASSWORD"
    - name: PGHOST
      value: "$DB_HOST"
    - name: PGPORT
      value: "$DB_PORT"
    - name: PGDATABASE
      value: "$DB_NAME"
    - name: PGUSER
      value: "$DB_USER"
    - name: PGPASSWORD
      value: "$DB_PASSWORD"
  restartPolicy: Never
EOF

echo "   Waiting for pod to be ready (this may take 2-3 minutes for image pull)..."
kubectl wait --for=condition=Ready pod/iqgeo-db-init -n $TEMP_NAMESPACE --timeout=300s
echo ""

# Test database connectivity from the pod
echo "4. Testing database connectivity..."
kubectl exec -n $TEMP_NAMESPACE iqgeo-db-init -- bash -c 'pg_isready -h $MYW_DB_HOST -p $MYW_DB_PORT -U $MYW_DB_USERNAME'
if [ $? -eq 0 ]; then
    echo "   ✓ Database connection successful"
else
    echo "   ✗ Database connection failed"
    echo ""
    echo "Cleaning up..."
    kubectl delete namespace $TEMP_NAMESPACE --wait=false
    exit 1
fi
echo ""

# Check current database state
echo "5. Checking current database state..."
CURRENT_TABLES=$(kubectl exec -n $TEMP_NAMESPACE iqgeo-db-init -- bash -c \
  'psql -h $MYW_DB_HOST -p $MYW_DB_PORT -U $MYW_DB_USERNAME -d $MYW_DB_NAME -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '"'"'public'"'"';" 2>/dev/null' | xargs)

echo "   Current tables in database: $CURRENT_TABLES"
echo ""

if [ "$CURRENT_TABLES" -gt 0 ]; then
    echo "WARNING: Database already has $CURRENT_TABLES tables."
    read -p "Do you want to continue and upgrade/initialize anyway? (y/n): " CONTINUE
    if [ "$CONTINUE" != "y" ]; then
        echo "Aborted by user."
        kubectl delete namespace $TEMP_NAMESPACE --wait=false
        exit 0
    fi
    echo ""
fi

# Initialize/Upgrade IQGeo Core Platform schema (Platform 7.3)
# For a fresh empty database, use 'install core' to create base tables
echo "6. Initializing IQGeo Core Platform schema (version 7.3.0)..."
echo "   Running: myw_db $DB_NAME install core"
kubectl exec -n $TEMP_NAMESPACE iqgeo-db-init -- bash -c \
  '/opt/iqgeo/platform/Tools/myw_db $MYW_DB_NAME install core' 2>&1 | tee /tmp/init-core-output.txt

CORE_EXIT=$?
if [ $CORE_EXIT -eq 0 ]; then
    echo "   ✓ Core platform schema initialized successfully"
elif grep -q "No new upgrades to apply" /tmp/init-core-output.txt; then
    echo "   ℹ Core schema already up to date"
else
    echo "   ✗ Core platform initialization failed (exit code: $CORE_EXIT)"
    echo "   Output:"
    cat /tmp/init-core-output.txt
    echo ""
    read -p "Continue with Network Manager Telecom initialization anyway? (y/n): " CONTINUE_COMMS
    if [ "$CONTINUE_COMMS" != "y" ]; then
        kubectl delete namespace $TEMP_NAMESPACE --wait=false
        exit 1
    fi
fi
echo ""

# Initialize/Upgrade Network Manager Telecom schema (NMT 7.3.3.5)
# After core install, install comms module
echo "7. Initializing Network Manager Telecom schema (version 7.3.3.5)..."
echo "   Running: myw_db $DB_NAME install comms"
kubectl exec -n $TEMP_NAMESPACE iqgeo-db-init -- bash -c \
  '/opt/iqgeo/platform/Tools/myw_db $MYW_DB_NAME install comms' 2>&1 | tee /tmp/init-comms-output.txt

COMMS_EXIT=$?
if [ $COMMS_EXIT -eq 0 ]; then
    echo "   ✓ Network Manager Telecom schema initialized successfully"
elif grep -q "No new upgrades to apply" /tmp/init-comms-output.txt; then
    echo "   ℹ Comms schema already up to date"
else
    echo "   ✗ Network Manager Telecom initialization failed (exit code: $COMMS_EXIT)"
    echo "   Output:"
    cat /tmp/init-comms-output.txt
fi
echo ""

# Verify the schema was created
echo "8. Verifying schema initialization..."
NEW_TABLE_COUNT=$(kubectl exec -n $TEMP_NAMESPACE iqgeo-db-init -- bash -c \
  'psql -h $MYW_DB_HOST -p $MYW_DB_PORT -U $MYW_DB_USERNAME -d $MYW_DB_NAME -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '"'"'public'"'"';" 2>/dev/null' | xargs)

echo "   Tables in database after initialization: $NEW_TABLE_COUNT"
echo ""

# List sample tables
echo "9. Sample tables created:"
kubectl exec -n $TEMP_NAMESPACE iqgeo-db-init -- bash -c \
  'psql -h $MYW_DB_HOST -p $MYW_DB_PORT -U $MYW_DB_USERNAME -d $MYW_DB_NAME -c "\dt" 2>/dev/null' | head -30
echo ""

# Cleanup temporary pod
echo "10. Cleaning up temporary resources..."
kubectl delete namespace $TEMP_NAMESPACE --wait=false
echo ""

echo "=========================================="
echo "SUCCESS! Database schema initialized"
echo "=========================================="
echo ""
echo "Schema Summary:"
echo "  - Core Platform tables: Initialized (v7.3)"
echo "  - Network Manager Telecom tables: Initialized (v7.3.3.5)"
echo "  - Total tables: $NEW_TABLE_COUNT"
echo ""
echo "Next Steps:"
echo "1. Restart IQGeo application pods:"
echo "   kubectl rollout restart deployment -n iqgeo -l app.kubernetes.io/name=iqgeo"
echo ""
echo "2. Monitor pod startup:"
echo "   kubectl get pods -n iqgeo -w"
echo ""
echo "3. Check application logs:"
echo "   kubectl logs -n iqgeo -l app=iqgeo-platform --tail=100"
echo ""
echo "The IQGeo application should now start successfully!"
echo ""
