#!/bin/bash
# Complete script: SSH to DB server, create database, install schemas

set -e

echo "=========================================="
echo "Create Database & Install IQGeo Schemas"
echo "=========================================="
echo ""

NAMESPACE="iqgeo"
DB_HOST="10.42.42.9"
DB_PORT="5432"
DB_NAME="iqgeo"
DB_USER="iqgeo"
DB_PASSWORD="IQGeoXHKtCMFtrPRrjV012026!"
IMAGE="harbor.delivery.iqgeo.cloud/nmti-trials/editions-nmt-comms-cloud:7.3"

echo "Step 1: Creating database on PostgreSQL server"
echo "Database: $DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"
echo ""

# SSH to database server and create database as postgres superuser
echo "1. Connecting to database server via SSH..."
ssh -o StrictHostKeyChecking=no root@$DB_HOST << 'ENDSSH'
echo "   Connected to database server"
echo ""

echo "2. Checking if database exists..."
DB_EXISTS=$(sudo -u postgres psql -t -c "SELECT 1 FROM pg_database WHERE datname='iqgeo';" 2>&1 | xargs || echo "")

if [ "$DB_EXISTS" = "1" ]; then
    echo "   Database exists, dropping it for clean install..."
    sudo -u postgres psql -c "DROP DATABASE IF EXISTS iqgeo;"
    echo "   ✓ Database dropped"
fi

echo ""
echo "3. Creating fresh database..."
sudo -u postgres psql -c "CREATE DATABASE iqgeo OWNER iqgeo;"
echo "   ✓ Database created"

echo ""
echo "4. Granting permissions..."
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE iqgeo TO iqgeo;"
sudo -u postgres psql -d iqgeo -c "GRANT ALL ON SCHEMA public TO iqgeo;"
sudo -u postgres psql -d iqgeo -c "ALTER DATABASE iqgeo OWNER TO iqgeo;"
echo "   ✓ Permissions granted"

echo ""
echo "5. Verifying database..."
sudo -u postgres psql -l | grep iqgeo
echo ""
ENDSSH

echo "   ✓ Database ready on server"
echo ""

# Now install schemas from Kubernetes
echo "Step 2: Installing IQGeo schemas"
echo ""

# Create temporary namespace
TEMP_NAMESPACE="db-install-$(date +%s)"
echo "6. Creating temporary installation pod..."
kubectl create namespace $TEMP_NAMESPACE > /dev/null 2>&1

kubectl get secret harbor-repository -n $NAMESPACE -o yaml 2>/dev/null | \
  sed "s/namespace: $NAMESPACE/namespace: $TEMP_NAMESPACE/" | \
  kubectl apply -f - > /dev/null 2>&1

cat <<EOF | kubectl apply -f - > /dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: db-install
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

kubectl wait --for=condition=Ready pod/db-install -n $TEMP_NAMESPACE --timeout=180s > /dev/null 2>&1
echo "   ✓ Pod ready"
echo ""

# Test connection
echo "7. Testing database connection..."
kubectl exec -n $TEMP_NAMESPACE db-install -- psql -c "SELECT version();" 2>&1 | head -3
echo "   ✓ Connection successful"
echo ""

# Install core
echo "8. Installing IQGeo Core Platform schema..."
kubectl exec -n $TEMP_NAMESPACE db-install -- /opt/iqgeo/platform/Tools/myw_db $DB_NAME install core 2>&1 | tee /tmp/core-install.txt | tail -20

CORE_EXIT=${PIPESTATUS[0]}
if [ $CORE_EXIT -eq 0 ]; then
    echo "   ✓ Core schema installed"
else
    echo "   ⚠ Exit code: $CORE_EXIT (checking if tables created)"
fi
echo ""

# Install comms
echo "9. Installing Network Manager Telecom schema..."
kubectl exec -n $TEMP_NAMESPACE db-install -- /opt/iqgeo/platform/Tools/myw_db $DB_NAME install comms 2>&1 | tee /tmp/comms-install.txt | tail -20

COMMS_EXIT=${PIPESTATUS[0]}
if [ $COMMS_EXIT -eq 0 ]; then
    echo "   ✓ Comms schema installed"
else
    echo "   ⚠ Exit code: $COMMS_EXIT (checking if tables created)"
fi
echo ""

# Verify
echo "10. Verifying installation..."
TABLE_COUNT=$(kubectl exec -n $TEMP_NAMESPACE db-install -- psql -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>&1 | xargs)

echo "    Total tables: $TABLE_COUNT"
echo ""

if [ "$TABLE_COUNT" -gt 30 ]; then
    echo "    ✓ SUCCESS! Database has $TABLE_COUNT tables"
    echo ""
    echo "11. Checking critical tables:"
    for TABLE in setting datasource myw_user; do
        EXISTS=$(kubectl exec -n $TEMP_NAMESPACE db-install -- psql -t -c "SELECT EXISTS (SELECT FROM pg_tables WHERE schemaname='public' AND tablename='$TABLE');" 2>&1 | xargs)
        if [ "$EXISTS" = "t" ]; then
            echo "    ✓ $TABLE exists"
        else
            echo "    ✗ $TABLE MISSING"
        fi
    done
    echo ""
    
    echo "12. Sample tables:"
    kubectl exec -n $TEMP_NAMESPACE db-install -- psql -c "\dt" 2>&1 | head -20
else
    echo "    ✗ Only $TABLE_COUNT tables (expected 30+)"
    echo ""
    echo "    Errors from installation:"
    grep -i "error\|exception\|failed" /tmp/core-install.txt /tmp/comms-install.txt 2>/dev/null | head -10
fi
echo ""

# Cleanup
echo "13. Cleaning up..."
kubectl delete namespace $TEMP_NAMESPACE --wait=false > /dev/null 2>&1
echo ""

echo "=========================================="
if [ "$TABLE_COUNT" -gt 30 ]; then
    echo "✓✓✓ DATABASE READY ✓✓✓"
    echo "=========================================="
    echo ""
    echo "Tables: $TABLE_COUNT"
    echo ""
    echo "NEXT STEP: Restart IQGeo application pods"
    echo "  ./restart-iqgeo-pods.sh"
    echo ""
    echo "Then check pods:"
    echo "  kubectl get pods -n iqgeo"
else
    echo "Installation Failed"
    echo "=========================================="
    echo ""
    echo "Tables: $TABLE_COUNT (expected 30+)"
    echo ""
    echo "Check logs:"
    echo "  cat /tmp/core-install.txt"
    echo "  cat /tmp/comms-install.txt"
fi
echo ""
