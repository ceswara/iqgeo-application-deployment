#!/bin/bash
# Script to verify what tables actually exist in the IQGeo database
# This will help diagnose why pods are still crashing after initialization

set -e

echo "=========================================="
echo "Database Table Verification"
echo "=========================================="
echo ""

# Configuration
NAMESPACE="iqgeo"
DB_HOST="10.42.42.9"
DB_PORT="5432"
DB_NAME="iqgeo"
DB_USER="iqgeo"
DB_PASSWORD="IQGeoXHKtCMFtrPRrjV012026!"  # ACTUAL working password (tested)

echo "Database Configuration:"
echo "  Host: $DB_HOST:$DB_PORT"
echo "  Database: $DB_NAME"
echo "  User: $DB_USER"
echo ""

# Create temporary namespace
TEMP_NAMESPACE="db-verify-$(date +%s)"
echo "1. Creating temporary verification pod..."
kubectl create namespace $TEMP_NAMESPACE

# Copy harbor secret if it exists
kubectl get secret harbor-repository -n $NAMESPACE -o yaml 2>/dev/null | \
  sed "s/namespace: $NAMESPACE/namespace: $TEMP_NAMESPACE/" | \
  kubectl apply -f - 2>/dev/null || echo "   Note: Using postgres image instead"

# Create pod with postgres client
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: db-verify
  namespace: $TEMP_NAMESPACE
spec:
  containers:
  - name: postgres
    image: postgres:16
    command: ["sleep", "600"]
    env:
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

echo "   Waiting for pod to be ready..."
kubectl wait --for=condition=Ready pod/db-verify -n $TEMP_NAMESPACE --timeout=120s
echo ""

# Test connection
echo "2. Testing database connection..."
kubectl exec -n $TEMP_NAMESPACE db-verify -- psql -c "SELECT version();" | head -5
echo ""

# Count total tables
echo "3. Counting tables in database..."
TABLE_COUNT=$(kubectl exec -n $TEMP_NAMESPACE db-verify -- psql -t -c \
  "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" | xargs)
echo "   Total tables: $TABLE_COUNT"
echo ""

# List all tables
echo "4. Listing all tables in database:"
kubectl exec -n $TEMP_NAMESPACE db-verify -- psql -c "\dt" 2>&1 | head -100
echo ""

# Check for specific critical tables
echo "5. Checking for critical IQGeo tables:"
CRITICAL_TABLES=("setting" "datasource" "myw_user" "myw_feature_type" "mywcom_fiber_segment")

for TABLE in "${CRITICAL_TABLES[@]}"; do
    EXISTS=$(kubectl exec -n $TEMP_NAMESPACE db-verify -- psql -t -c \
      "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = '$TABLE');" | xargs)
    
    if [ "$EXISTS" = "t" ]; then
        echo "   ✓ $TABLE - EXISTS"
    else
        echo "   ✗ $TABLE - MISSING"
    fi
done
echo ""

# Check what the application ConfigMap says about database
echo "6. Checking application ConfigMap database settings:"
kubectl get configmap -n $NAMESPACE -o yaml | grep -A 5 "MYW_DB\|PGHOST\|PGDATABASE" | head -20
echo ""

# Check if there are multiple databases
echo "7. Listing all databases on the server:"
kubectl exec -n $TEMP_NAMESPACE db-verify -- psql -t -c "\l" | grep -v "template\|postgres" | head -20
echo ""

# Cleanup
echo "8. Cleaning up..."
kubectl delete namespace $TEMP_NAMESPACE --wait=false
echo ""

echo "=========================================="
echo "Verification Complete"
echo "=========================================="
echo ""

if [ "$TABLE_COUNT" -eq 0 ]; then
    echo "PROBLEM: Database is EMPTY (0 tables)"
    echo ""
    echo "Possible causes:"
    echo "1. The initialization script connected to the wrong database"
    echo "2. The myw_db tool failed but didn't report an error"
    echo "3. Database credentials don't have CREATE TABLE permissions"
    echo ""
    echo "Next steps:"
    echo "1. Check /tmp/init-core-output.txt and /tmp/init-comms-output.txt for errors"
    echo "2. Verify database user '$DB_USER' has permissions:"
    echo "   GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
    echo "3. Re-run initialize-database-schema.sh"
else
    echo "Database has $TABLE_COUNT tables"
    echo ""
    if [ "$TABLE_COUNT" -lt 10 ]; then
        echo "WARNING: Very few tables. IQGeo typically has 100+ tables."
        echo "The initialization may have been incomplete."
    fi
fi
echo ""
