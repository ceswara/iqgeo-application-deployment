#!/bin/bash
# Script to clean database and perform fresh initialization

set -e

echo "=========================================="
echo "Clean Database & Fresh Initialization"
echo "=========================================="
echo ""

NAMESPACE="iqgeo"
DB_HOST="10.42.42.9"
DB_PORT="5432"
DB_NAME="iqgeo"
DB_USER="iqgeo"
DB_PASSWORD="IQGeoXHKtCMFtrPRrjV012026!"
IMAGE="harbor.delivery.iqgeo.cloud/nmti-trials/editions-nmt-comms-cloud:7.3"

echo "Database Configuration:"
echo "  Host: $DB_HOST:$DB_PORT"
echo "  Database: $DB_NAME"
echo "  User: $DB_USER"
echo ""

# Create temporary namespace
TEMP_NAMESPACE="db-clean-$(date +%s)"
echo "1. Creating temporary pod..."
kubectl create namespace $TEMP_NAMESPACE

kubectl get secret harbor-repository -n $NAMESPACE -o yaml 2>/dev/null | \
  sed "s/namespace: $NAMESPACE/namespace: $TEMP_NAMESPACE/" | \
  kubectl apply -f -

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: db-clean
  namespace: $TEMP_NAMESPACE
spec:
  containers:
  - name: iqgeo
    image: $IMAGE
    command: ["sleep", "600"]
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
  imagePullSecrets:
  - name: harbor-repository
  restartPolicy: Never
EOF

echo "   Waiting for pod to be ready..."
kubectl wait --for=condition=Ready pod/db-clean -n $TEMP_NAMESPACE --timeout=180s
echo ""

# Check current state
echo "2. Checking current database state..."
kubectl exec -n $TEMP_NAMESPACE db-clean -- psql -c "\dn" 2>&1 | head -20
echo ""

# Drop and recreate database for clean slate
echo "3. Cleaning database (dropping and recreating)..."
echo "   WARNING: This will delete all data in the database!"
echo ""

kubectl exec -n $TEMP_NAMESPACE db-clean -- psql -d postgres -c "DROP DATABASE IF EXISTS $DB_NAME;" 2>&1
kubectl exec -n $TEMP_NAMESPACE db-clean -- psql -d postgres -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;" 2>&1

echo "   ✓ Database recreated"
echo ""

# Install core schema
echo "4. Installing IQGeo Core Platform schema..."
kubectl exec -n $TEMP_NAMESPACE db-clean -- bash -c \
  '/opt/iqgeo/platform/Tools/myw_db $MYW_DB_NAME install core' 2>&1 | tee /tmp/install-core.txt

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo "   ✓ Core schema installed"
else
    echo "   ✗ Core installation failed"
    cat /tmp/install-core.txt | tail -30
fi
echo ""

# Install comms schema
echo "5. Installing Network Manager Telecom schema..."
kubectl exec -n $TEMP_NAMESPACE db-clean -- bash -c \
  '/opt/iqgeo/platform/Tools/myw_db $MYW_DB_NAME install comms' 2>&1 | tee /tmp/install-comms.txt

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo "   ✓ Comms schema installed"
else
    echo "   ✗ Comms installation failed"
    cat /tmp/install-comms.txt | tail -30
fi
echo ""

# Verify tables
echo "6. Verifying tables were created..."
TABLE_COUNT=$(kubectl exec -n $TEMP_NAMESPACE db-clean -- psql -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>&1 | xargs)

echo "   Total tables: $TABLE_COUNT"
echo ""

if [ "$TABLE_COUNT" -gt 50 ]; then
    echo "   ✓ Database initialized successfully with $TABLE_COUNT tables!"
    
    # List sample tables
    echo ""
    echo "7. Sample tables created:"
    kubectl exec -n $TEMP_NAMESPACE db-clean -- psql -c "\dt" 2>&1 | head -30
else
    echo "   ✗ Insufficient tables created: $TABLE_COUNT"
fi
echo ""

# Cleanup
echo "8. Cleaning up..."
kubectl delete namespace $TEMP_NAMESPACE --wait=false

echo ""
echo "=========================================="
echo "Clean & Initialize Complete"
echo "=========================================="
echo ""

if [ "$TABLE_COUNT" -gt 50 ]; then
    echo "✓ Database ready with $TABLE_COUNT tables"
    echo ""
    echo "Next: Restart IQGeo pods:"
    echo "  cd /opt/iqgeo-application-deployment"
    echo "  ./restart-iqgeo-pods.sh"
else
    echo "✗ Database initialization incomplete"
    echo "Check /tmp/install-core.txt and /tmp/install-comms.txt for errors"
fi
echo ""
