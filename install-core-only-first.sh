#!/bin/bash
# Install CORE first, verify it commits, THEN install comms separately

set -e

echo "=========================================="
echo "Install Core First (Separate Transaction)"
echo "=========================================="
echo ""

DB_HOST="10.42.42.9"
DB_NAME="iqgeo"
DB_USER="iqgeo"
DB_PASSWORD="IQGeoXHKtCMFtrPRrjV012026!"
IMAGE="harbor.delivery.iqgeo.cloud/nmti-trials/editions-nmt-comms-cloud:7.3"

echo "Step 1: Drop and recreate database"
ssh -o StrictHostKeyChecking=no root@$DB_HOST << 'ENDSSH'
sudo -u postgres psql -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='iqgeo';" 2>&1 | head -1
sudo -u postgres psql -c "DROP DATABASE IF EXISTS iqgeo;" 2>&1 | grep DROP
sudo -u postgres psql -c "CREATE DATABASE iqgeo OWNER iqgeo;" 2>&1 | grep CREATE
sudo -u postgres psql -d iqgeo -c "CREATE EXTENSION postgis;" 2>&1 | grep CREATE
sudo -u postgres psql -d iqgeo -c "CREATE EXTENSION postgis_topology;" 2>&1 | grep CREATE
echo "✓ Database ready"
ENDSSH

echo ""
echo "Step 2: Create installation pod"
NAMESPACE="iqgeo"
TEMP_NS="core-$(date +%s)"

kubectl create namespace $TEMP_NS > /dev/null 2>&1
kubectl get secret harbor-repository -n $NAMESPACE -o yaml 2>/dev/null | sed "s/namespace: $NAMESPACE/namespace: $TEMP_NS/" | kubectl apply -f - > /dev/null 2>&1

cat <<EOF | kubectl apply -f - > /dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: core
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

kubectl wait --for=condition=Ready pod/core -n $TEMP_NS --timeout=180s > /dev/null 2>&1
echo "✓ Pod ready"
echo ""

echo "Step 3: Install CORE schema ONLY"
echo "(This will take 2-3 minutes...)"
echo ""

kubectl exec -n $TEMP_NS core -- /opt/iqgeo/platform/Tools/myw_db $DB_NAME install core 2>&1 | tail -5

echo ""
echo "Step 4: Check if core tables exist (wait 5 seconds for commit)"
sleep 5

# Check via SSH directly on the database server
echo ""
echo "Checking tables directly on database server..."
ssh -o StrictHostKeyChecking=no root@$DB_HOST << ENDSSH2
TABLE_COUNT=\$(PGPASSWORD="$DB_PASSWORD" psql -h localhost -U $DB_USER -d $DB_NAME -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" | xargs)
echo "Tables in database: \$TABLE_COUNT"
echo ""

if [ "\$TABLE_COUNT" -gt 30 ]; then
    echo "✓ Core tables exist!"
    echo ""
    echo "Sample tables:"
    PGPASSWORD="$DB_PASSWORD" psql -h localhost -U $DB_USER -d $DB_NAME -c "\dt" | head -20
else
    echo "✗ Still only \$TABLE_COUNT tables - checking what exists:"
    PGPASSWORD="$DB_PASSWORD" psql -h localhost -U $DB_USER -d $DB_NAME -c "\dt"
fi
ENDSSH2

kubectl delete namespace $TEMP_NS --wait=false > /dev/null 2>&1

echo ""
echo "=========================================="
echo "Core Installation Check Complete"
echo "=========================================="
