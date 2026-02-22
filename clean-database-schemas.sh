#!/bin/bash
# Script to clean database schemas and perform fresh initialization
# This drops schemas instead of the database (doesn't require superuser)

set -e

echo "=========================================="
echo "Clean Database Schemas & Fresh Install"
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
echo "2. Checking current database schemas..."
kubectl exec -n $TEMP_NAMESPACE db-clean -- psql -c "\dn" 2>&1
echo ""

# Drop all existing schemas and their contents
echo "3. Dropping existing schemas (data, myw, public)..."
echo "   WARNING: This will delete all data in these schemas!"
echo ""

kubectl exec -n $TEMP_NAMESPACE db-clean -- psql -c "DROP SCHEMA IF EXISTS data CASCADE;" 2>&1
echo "   ✓ Dropped 'data' schema"

kubectl exec -n $TEMP_NAMESPACE db-clean -- psql -c "DROP SCHEMA IF EXISTS myw CASCADE;" 2>&1
echo "   ✓ Dropped 'myw' schema"

kubectl exec -n $TEMP_NAMESPACE db-clean -- psql -c "DROP SCHEMA IF EXISTS public CASCADE;" 2>&1
echo "   ✓ Dropped 'public' schema"

kubectl exec -n $TEMP_NAMESPACE db-clean -- psql -c "CREATE SCHEMA public AUTHORIZATION $DB_USER;" 2>&1
kubectl exec -n $TEMP_NAMESPACE db-clean -- psql -c "GRANT ALL ON SCHEMA public TO $DB_USER;" 2>&1
echo "   ✓ Recreated 'public' schema"
echo ""

# Verify schemas are clean
echo "4. Verifying database is clean..."
TABLE_COUNT_BEFORE=$(kubectl exec -n $TEMP_NAMESPACE db-clean -- psql -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>&1 | xargs)
echo "   Tables before installation: $TABLE_COUNT_BEFORE"
echo ""

# Install core schema
echo "5. Installing IQGeo Core Platform schema..."
kubectl exec -n $TEMP_NAMESPACE db-clean -- /opt/iqgeo/platform/Tools/myw_db $DB_NAME install core 2>&1 | tee /tmp/install-core.txt

CORE_EXIT=${PIPESTATUS[0]}
if [ $CORE_EXIT -eq 0 ]; then
    echo "   ✓ Core schema installed successfully"
elif grep -q "already installed" /tmp/install-core.txt; then
    echo "   ℹ Core already installed"
else
    echo "   ✗ Core installation failed (exit code: $CORE_EXIT)"
    echo "   Last 30 lines of output:"
    tail -30 /tmp/install-core.txt
fi
echo ""

# Install comms schema
echo "6. Installing Network Manager Telecom schema..."
kubectl exec -n $TEMP_NAMESPACE db-clean -- /opt/iqgeo/platform/Tools/myw_db $DB_NAME install comms 2>&1 | tee /tmp/install-comms.txt

COMMS_EXIT=${PIPESTATUS[0]}
if [ $COMMS_EXIT -eq 0 ]; then
    echo "   ✓ Comms schema installed successfully"
elif grep -q "already installed\|No new upgrades" /tmp/install-comms.txt; then
    echo "   ℹ Comms already up to date"
else
    echo "   ✗ Comms installation failed (exit code: $COMMS_EXIT)"
    echo "   Last 30 lines of output:"
    tail -30 /tmp/install-comms.txt
fi
echo ""

# Verify tables
echo "7. Verifying tables were created..."
TABLE_COUNT=$(kubectl exec -n $TEMP_NAMESPACE db-clean -- psql -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>&1 | xargs)

echo "   Total tables: $TABLE_COUNT"
echo ""

if [ "$TABLE_COUNT" -gt 50 ]; then
    echo "   ✓ Database initialized successfully with $TABLE_COUNT tables!"
    
    # List sample tables
    echo ""
    echo "8. Sample tables created:"
    kubectl exec -n $TEMP_NAMESPACE db-clean -- psql -c "\dt" 2>&1 | head -30
    
    # Check for critical tables
    echo ""
    echo "9. Verifying critical IQGeo tables:"
    CRITICAL_TABLES=("setting" "datasource" "myw_user")
    for TABLE in "${CRITICAL_TABLES[@]}"; do
        EXISTS=$(kubectl exec -n $TEMP_NAMESPACE db-clean -- psql -t -c "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = '$TABLE');" 2>&1 | xargs)
        if [ "$EXISTS" = "t" ]; then
            echo "   ✓ $TABLE"
        else
            echo "   ✗ $TABLE - MISSING"
        fi
    done
else
    echo "   ✗ Insufficient tables created: $TABLE_COUNT"
    echo "   Expected at least 50 tables"
fi
echo ""

# Cleanup
echo "10. Cleaning up..."
kubectl delete namespace $TEMP_NAMESPACE --wait=false

echo ""
echo "=========================================="
echo "Schema Cleaning & Installation Complete"
echo "=========================================="
echo ""

if [ "$TABLE_COUNT" -gt 50 ]; then
    echo "✓✓✓ SUCCESS! Database ready with $TABLE_COUNT tables"
    echo ""
    echo "Next: Restart IQGeo pods:"
    echo "  cd /opt/iqgeo-application-deployment"
    echo "  ./restart-iqgeo-pods.sh"
else
    echo "✗ Database initialization incomplete"
    echo "Tables created: $TABLE_COUNT (expected 50+)"
    echo ""
    echo "Check /tmp/install-core.txt and /tmp/install-comms.txt for errors"
fi
echo ""
