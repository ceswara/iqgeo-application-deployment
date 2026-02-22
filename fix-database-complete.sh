#!/bin/bash
# COMPLETE database fix script - handles all cases
# Creates database if missing, cleans schemas, installs fresh

set -e

echo "=========================================="
echo "COMPLETE Database Fix & Installation"
echo "=========================================="
echo ""

NAMESPACE="iqgeo"
DB_HOST="10.42.42.9"
DB_PORT="5432"
DB_NAME="iqgeo"
DB_USER="iqgeo"
DB_PASSWORD="IQGeoXHKtCMFtrPRrjV012026!"
IMAGE="harbor.delivery.iqgeo.cloud/nmti-trials/editions-nmt-comms-cloud:7.3"

echo "Database: $DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"
echo ""

# Create temporary namespace
TEMP_NAMESPACE="db-fix-$(date +%s)"
echo "1. Creating temporary pod..."
kubectl create namespace $TEMP_NAMESPACE > /dev/null 2>&1

kubectl get secret harbor-repository -n $NAMESPACE -o yaml 2>/dev/null | \
  sed "s/namespace: $NAMESPACE/namespace: $TEMP_NAMESPACE/" | \
  kubectl apply -f - > /dev/null 2>&1

cat <<EOF | kubectl apply -f - > /dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: db-fix
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
    - name: PGUSER
      value: "$DB_USER"
    - name: PGPASSWORD
      value: "$DB_PASSWORD"
  imagePullSecrets:
  - name: harbor-repository
  restartPolicy: Never
EOF

kubectl wait --for=condition=Ready pod/db-fix -n $TEMP_NAMESPACE --timeout=180s > /dev/null 2>&1
echo "   ✓ Pod ready"
echo ""

# Check if database exists
echo "2. Checking if database exists..."
DB_EXISTS=$(kubectl exec -n $TEMP_NAMESPACE db-fix -- psql -d postgres -t -c "SELECT 1 FROM pg_database WHERE datname='$DB_NAME';" 2>&1 | xargs || echo "")

if [ "$DB_EXISTS" = "1" ]; then
    echo "   ✓ Database exists"
    echo ""
    
    echo "3. Dropping all schemas to clean database..."
    kubectl exec -n $TEMP_NAMESPACE db-fix -- psql -d $DB_NAME -c "DROP SCHEMA IF EXISTS data CASCADE;" 2>&1 | grep -v "does not exist" || true
    kubectl exec -n $TEMP_NAMESPACE db-fix -- psql -d $DB_NAME -c "DROP SCHEMA IF EXISTS myw CASCADE;" 2>&1 | grep -v "does not exist" || true
    kubectl exec -n $TEMP_NAMESPACE db-fix -- psql -d $DB_NAME -c "DROP SCHEMA IF EXISTS public CASCADE;" 2>&1 | grep -v "does not exist" || true
    kubectl exec -n $TEMP_NAMESPACE db-fix -- psql -d $DB_NAME -c "CREATE SCHEMA public;" 2>&1 || true
    echo "   ✓ Schemas cleaned"
else
    echo "   ✗ Database does not exist, creating it..."
    kubectl exec -n $TEMP_NAMESPACE db-fix -- psql -d postgres -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;" 2>&1
    echo "   ✓ Database created"
fi
echo ""

# Set PGDATABASE for subsequent commands
export PGDATABASE=$DB_NAME

echo "4. Installing IQGeo Core Platform schema..."
kubectl exec -n $TEMP_NAMESPACE db-fix -- env PGDATABASE=$DB_NAME /opt/iqgeo/platform/Tools/myw_db $DB_NAME install core 2>&1 | tee /tmp/install-core-final.txt | grep -E "Upgrading|Creating|✓|✗|error|Error|ERROR" || true

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo "   ✓ Core installed"
else
    echo "   ⚠ Core install had issues (checking if tables created anyway)"
fi
echo ""

echo "5. Installing Network Manager Telecom schema..."
kubectl exec -n $TEMP_NAMESPACE db-fix -- env PGDATABASE=$DB_NAME /opt/iqgeo/platform/Tools/myw_db $DB_NAME install comms 2>&1 | tee /tmp/install-comms-final.txt | grep -E "Upgrading|Creating|✓|✗|error|Error|ERROR" || true

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo "   ✓ Comms installed"
else
    echo "   ⚠ Comms install had issues (checking if tables created anyway)"
fi
echo ""

# Verify tables
echo "6. Verifying tables..."
TABLE_COUNT=$(kubectl exec -n $TEMP_NAMESPACE db-fix -- psql -d $DB_NAME -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>&1 | xargs)

echo "   Total tables: $TABLE_COUNT"
echo ""

if [ "$TABLE_COUNT" -gt 30 ]; then
    echo "   ✓✓✓ SUCCESS! Database has $TABLE_COUNT tables"
    echo ""
    
    # Check critical tables
    echo "7. Checking critical tables:"
    for TABLE in setting datasource myw_user; do
        EXISTS=$(kubectl exec -n $TEMP_NAMESPACE db-fix -- psql -d $DB_NAME -t -c "SELECT EXISTS (SELECT FROM pg_tables WHERE schemaname='public' AND tablename='$TABLE');" 2>&1 | xargs)
        if [ "$EXISTS" = "t" ]; then
            echo "   ✓ $TABLE"
        else
            echo "   ✗ $TABLE"
        fi
    done
else
    echo "   ✗ Only $TABLE_COUNT tables created (need 30+)"
    echo "   Showing errors from installation:"
    grep -i error /tmp/install-core-final.txt /tmp/install-comms-final.txt 2>/dev/null | head -20
fi
echo ""

# Cleanup
echo "8. Cleaning up..."
kubectl delete namespace $TEMP_NAMESPACE --wait=false > /dev/null 2>&1

echo ""
echo "=========================================="
if [ "$TABLE_COUNT" -gt 30 ]; then
    echo "✓✓✓ DATABASE READY! ✓✓✓"
    echo "=========================================="
    echo ""
    echo "Tables created: $TABLE_COUNT"
    echo ""
    echo "NEXT STEP: Restart pods to use the new database"
    echo "  ./restart-iqgeo-pods.sh"
else
    echo "Installation Issues"
    echo "=========================================="
    echo ""
    echo "Tables: $TABLE_COUNT (expected 30+)"
    echo "Check /tmp/install-core-final.txt and /tmp/install-comms-final.txt"
fi
echo ""
