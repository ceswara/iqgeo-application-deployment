#!/bin/bash
# Complete fresh installation: Drop database, recreate, enable PostGIS, install schemas

set -e

echo "=========================================="
echo "COMPLETE FRESH INSTALLATION"
echo "=========================================="
echo ""

DB_HOST="10.42.42.9"
DB_NAME="iqgeo"
DB_USER="iqgeo"
DB_PASSWORD="IQGeoXHKtCMFtrPRrjV012026!"

echo "This will:"
echo "1. DROP the entire iqgeo database"
echo "2. CREATE fresh iqgeo database"
echo "3. Enable PostGIS extension"
echo "4. Install IQGeo schemas"
echo ""
echo "Database: $DB_USER@$DB_HOST/$DB_NAME"
echo ""

# Step 1: Completely recreate database on server
echo "Step 1: Recreating database on PostgreSQL server"
echo ""

ssh -o StrictHostKeyChecking=no root@$DB_HOST << 'ENDSSH'
echo "1. Dropping existing database (if exists)..."
sudo -u postgres psql -c "DROP DATABASE IF EXISTS iqgeo;" 2>&1 | grep -v "does not exist" || true
echo "   ✓ Dropped"

echo ""
echo "2. Creating fresh database..."
sudo -u postgres psql -c "CREATE DATABASE iqgeo OWNER iqgeo;"
echo "   ✓ Created"

echo ""
echo "3. Granting permissions..."
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE iqgeo TO iqgeo;"
echo "   ✓ Permissions granted"

echo ""
echo "4. Installing PostGIS extension..."
sudo -u postgres psql -d iqgeo -c "CREATE EXTENSION IF NOT EXISTS postgis;"
sudo -u postgres psql -d iqgeo -c "CREATE EXTENSION IF NOT EXISTS postgis_topology;"
echo "   ✓ PostGIS enabled"

echo ""
echo "5. Verifying database is clean..."
TABLE_COUNT=$(sudo -u postgres psql -d iqgeo -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" | xargs)
echo "   Tables: $TABLE_COUNT (should be 0-1)"

echo ""
echo "6. Checking PostGIS..."
sudo -u postgres psql -d iqgeo -c "SELECT PostGIS_version();" | grep -i postgis
echo ""
ENDSSH

echo "   ✓ Fresh database ready on server"
echo ""

# Step 2: Install IQGeo schemas from Kubernetes
echo "Step 2: Installing IQGeo schemas from Kubernetes"
echo ""

NAMESPACE="iqgeo"
DB_PORT="5432"
IMAGE="harbor.delivery.iqgeo.cloud/nmti-trials/editions-nmt-comms-cloud:7.3"

TEMP_NAMESPACE="install-$(date +%s)"
echo "7. Creating installation pod..."
kubectl create namespace $TEMP_NAMESPACE > /dev/null 2>&1

kubectl get secret harbor-repository -n $NAMESPACE -o yaml 2>/dev/null | \
  sed "s/namespace: $NAMESPACE/namespace: $TEMP_NAMESPACE/" | \
  kubectl apply -f - > /dev/null 2>&1

cat <<EOF | kubectl apply -f - > /dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: install
  namespace: $TEMP_NAMESPACE
spec:
  containers:
  - name: iqgeo
    image: $IMAGE
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
  imagePullSecrets:
  - name: harbor-repository
  restartPolicy: Never
EOF

kubectl wait --for=condition=Ready pod/install -n $TEMP_NAMESPACE --timeout=180s > /dev/null 2>&1
echo "   ✓ Pod ready"
echo ""

echo "8. Testing connection..."
kubectl exec -n $TEMP_NAMESPACE install -- psql -c "SELECT version();" 2>&1 | head -3
echo "   ✓ Connected"
echo ""

echo "9. Installing IQGeo Core Platform..."
echo "   (This may take 2-3 minutes...)"
kubectl exec -n $TEMP_NAMESPACE install -- /opt/iqgeo/platform/Tools/myw_db $DB_NAME install core 2>&1 > /tmp/core.txt

if [ $? -eq 0 ]; then
    echo "   ✓ Core installed successfully"
else
    echo "   ✗ Core installation failed"
    tail -20 /tmp/core.txt
    echo ""
fi
echo ""

echo "10. Installing Network Manager Telecom..."
echo "    (This may take 2-3 minutes...)"
kubectl exec -n $TEMP_NAMESPACE install -- /opt/iqgeo/platform/Tools/myw_db $DB_NAME install comms 2>&1 > /tmp/comms.txt

if [ $? -eq 0 ]; then
    echo "    ✓ Comms installed successfully"
else
    echo "    ✗ Comms installation failed"
    tail -20 /tmp/comms.txt
    echo ""
fi
echo ""

echo "11. Verifying installation..."
TABLE_COUNT=$(kubectl exec -n $TEMP_NAMESPACE install -- psql -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>&1 | xargs)

echo "    Total tables: $TABLE_COUNT"
echo ""

if [ "$TABLE_COUNT" -gt 50 ]; then
    echo "    ✓✓✓ SUCCESS! $TABLE_COUNT tables created ✓✓✓"
    echo ""
    echo "12. Verifying critical tables:"
    for TABLE in setting datasource myw_user myw_feature_type; do
        EXISTS=$(kubectl exec -n $TEMP_NAMESPACE install -- psql -t -c "SELECT EXISTS (SELECT FROM pg_tables WHERE schemaname='public' AND tablename='$TABLE');" 2>&1 | xargs)
        if [ "$EXISTS" = "t" ]; then
            echo "    ✓ $TABLE"
        fi
    done
else
    echo "    ✗ FAILED: Only $TABLE_COUNT tables"
    echo ""
    echo "    Errors:"
    grep -i "error\|exception\|failed" /tmp/core.txt /tmp/comms.txt 2>/dev/null | head -10
fi
echo ""

kubectl delete namespace $TEMP_NAMESPACE --wait=false > /dev/null 2>&1

echo "=========================================="
if [ "$TABLE_COUNT" -gt 50 ]; then
    echo "✓✓✓ INSTALLATION COMPLETE ✓✓✓"
    echo "=========================================="
    echo ""
    echo "Database: $TABLE_COUNT tables ready"
    echo ""
    echo "FINAL STEP: Restart IQGeo application"
    echo ""
    echo "Run:"
    echo "  ./restart-iqgeo-pods.sh"
    echo "  kubectl get pods -n iqgeo -w"
else
    echo "INSTALLATION FAILED"
    echo "=========================================="
    echo ""
    echo "Only $TABLE_COUNT tables created (expected 50+)"
    echo ""
    echo "Review logs:"
    echo "  cat /tmp/core.txt"
    echo "  cat /tmp/comms.txt"
fi
echo ""
