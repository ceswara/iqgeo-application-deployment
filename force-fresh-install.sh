#!/bin/bash
# FORCE fresh installation by dropping database completely

set -e

echo "=========================================="
echo "FORCE FRESH INSTALL - Drop & Recreate DB"
echo "=========================================="
echo ""

DB_HOST="10.42.42.9"
DB_NAME="iqgeo"
DB_USER="iqgeo"
DB_PASSWORD="IQGeoXHKtCMFtrPRrjV012026!"
IMAGE="harbor.delivery.iqgeo.cloud/nmti-trials/editions-nmt-comms-cloud:7.3"

echo "Step 1: COMPLETELY DROP and recreate database"
echo ""

ssh -o StrictHostKeyChecking=no root@$DB_HOST << 'ENDSSH'
echo "Terminating all connections to iqgeo database..."
sudo -u postgres psql -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='iqgeo' AND pid <> pg_backend_pid();" 2>&1 | grep -v "0 rows" || true

echo "Dropping database..."
sudo -u postgres psql -c "DROP DATABASE IF EXISTS iqgeo;" 2>&1

echo "Creating fresh database..."
sudo -u postgres psql -c "CREATE DATABASE iqgeo OWNER iqgeo;"

echo "Installing PostGIS..."
sudo -u postgres psql -d iqgeo -c "CREATE EXTENSION postgis;"
sudo -u postgres psql -d iqgeo -c "CREATE EXTENSION postgis_topology;"

echo "✓ Fresh database created with PostGIS"
ENDSSH

echo ""
echo "Step 2: Install schemas"
echo ""

NAMESPACE="iqgeo"
TEMP_NS="install-$(date +%s)"

kubectl create namespace $TEMP_NS > /dev/null 2>&1
kubectl get secret harbor-repository -n $NAMESPACE -o yaml 2>/dev/null | sed "s/namespace: $NAMESPACE/namespace: $TEMP_NS/" | kubectl apply -f - > /dev/null 2>&1

cat <<EOF | kubectl apply -f - > /dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: install
  namespace: $TEMP_NS
spec:
  containers:
  - name: iqgeo
    image: $IMAGE
    command: ["sleep", "3600"]
    env:
    - name: PGHOST
      value: "$DB_HOST"
    - name: PGDATABASE
      value: "$DB_NAME"
    - name: PGUSER
      value: "$DB_USER"
    - name: PGPASSWORD
      value: "$DB_PASSWORD"
    - name: MYW_DB_HOST
      value: "$DB_HOST"
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

kubectl wait --for=condition=Ready pod/install -n $TEMP_NS --timeout=180s > /dev/null 2>&1
echo "Pod ready"
echo ""

echo "Installing CORE..."
kubectl exec -n $TEMP_NS install -- /opt/iqgeo/platform/Tools/myw_db $DB_NAME install core
echo ""

TABLE_COUNT=$(kubectl exec -n $TEMP_NS install -- psql -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public';" | xargs)
echo "Tables after core: $TABLE_COUNT"
echo ""

if [ "$TABLE_COUNT" -gt 30 ]; then
    echo "✓ Core SUCCESS"
    echo ""
    echo "Installing COMMS..."
    kubectl exec -n $TEMP_NS install -- /opt/iqgeo/platform/Tools/myw_db $DB_NAME install comms
    
    TABLE_COUNT=$(kubectl exec -n $TEMP_NS install -- psql -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public';" | xargs)
    echo ""
    echo "Final tables: $TABLE_COUNT"
fi

kubectl delete namespace $TEMP_NS --wait=false > /dev/null 2>&1

echo ""
if [ "$TABLE_COUNT" -gt 50 ]; then
    echo "✓✓✓ SUCCESS - $TABLE_COUNT TABLES ✓✓✓"
    echo ""
    echo "RUN NOW: ./restart-iqgeo-pods.sh"
else
    echo "✗ FAILED - $TABLE_COUNT tables"
fi
