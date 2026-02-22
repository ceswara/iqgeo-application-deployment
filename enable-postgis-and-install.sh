#!/bin/bash
# Enable PostGIS extension and install IQGeo schemas

set -e

echo "=========================================="
echo "Enable PostGIS & Install IQGeo"
echo "=========================================="
echo ""

DB_HOST="10.42.42.9"
DB_NAME="iqgeo"

echo "Step 1: Installing PostGIS extension in database"
echo ""

# SSH to database server and enable PostGIS
ssh -o StrictHostKeyChecking=no root@$DB_HOST << 'ENDSSH'
echo "1. Installing PostGIS packages (if not already installed)..."
apt-get update -qq > /dev/null 2>&1 || yum check-update -q > /dev/null 2>&1 || true
apt-get install -y -qq postgresql-14-postgis-3 > /dev/null 2>&1 || \
  yum install -y -q postgis33_14 > /dev/null 2>&1 || \
  echo "   PostGIS may already be installed"
echo "   ✓ PostGIS packages ready"
echo ""

echo "2. Enabling PostGIS extension in iqgeo database..."
sudo -u postgres psql -d iqgeo -c "CREATE EXTENSION IF NOT EXISTS postgis;"
sudo -u postgres psql -d iqgeo -c "CREATE EXTENSION IF NOT EXISTS postgis_topology;"
echo "   ✓ PostGIS enabled"
echo ""

echo "3. Verifying PostGIS..."
sudo -u postgres psql -d iqgeo -c "SELECT PostGIS_version();" | grep -i postgis
echo ""
ENDSSH

echo "   ✓ PostGIS ready on server"
echo ""

# Now run the installation using the existing script
echo "Step 2: Installing IQGeo schemas"
echo ""

NAMESPACE="iqgeo"
DB_PORT="5432"
DB_USER="iqgeo"
DB_PASSWORD="IQGeoXHKtCMFtrPRrjV012026!"
IMAGE="harbor.delivery.iqgeo.cloud/nmti-trials/editions-nmt-comms-cloud:7.3"

# Create temporary namespace
TEMP_NAMESPACE="db-install-$(date +%s)"
echo "4. Creating installation pod..."
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

# Install core
echo "5. Installing IQGeo Core Platform schema..."
kubectl exec -n $TEMP_NAMESPACE db-install -- /opt/iqgeo/platform/Tools/myw_db $DB_NAME install core 2>&1 | tee /tmp/core-final.txt | tail -30

CORE_EXIT=${PIPESTATUS[0]}
if [ $CORE_EXIT -eq 0 ]; then
    echo ""
    echo "   ✓ Core schema installed successfully"
else
    echo ""
    echo "   ⚠ Exit code: $CORE_EXIT"
    grep -i "error" /tmp/core-final.txt | head -5 || true
fi
echo ""

# Install comms
echo "6. Installing Network Manager Telecom schema..."
kubectl exec -n $TEMP_NAMESPACE db-install -- /opt/iqgeo/platform/Tools/myw_db $DB_NAME install comms 2>&1 | tee /tmp/comms-final.txt | tail -30

COMMS_EXIT=${PIPESTATUS[0]}
if [ $COMMS_EXIT -eq 0 ]; then
    echo ""
    echo "   ✓ Comms schema installed successfully"
else
    echo ""
    echo "   ⚠ Exit code: $COMMS_EXIT"
    grep -i "error" /tmp/comms-final.txt | head -5 || true
fi
echo ""

# Verify
echo "7. Verifying installation..."
TABLE_COUNT=$(kubectl exec -n $TEMP_NAMESPACE db-install -- psql -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>&1 | xargs)

echo "   Total tables: $TABLE_COUNT"
echo ""

if [ "$TABLE_COUNT" -gt 50 ]; then
    echo "   ✓✓✓ SUCCESS! Database has $TABLE_COUNT tables ✓✓✓"
    echo ""
    echo "8. Critical tables:"
    for TABLE in setting datasource myw_user myw_feature_type; do
        EXISTS=$(kubectl exec -n $TEMP_NAMESPACE db-install -- psql -t -c "SELECT EXISTS (SELECT FROM pg_tables WHERE schemaname='public' AND tablename='$TABLE');" 2>&1 | xargs)
        if [ "$EXISTS" = "t" ]; then
            echo "   ✓ $TABLE"
        else
            echo "   ✗ $TABLE MISSING"
        fi
    done
else
    echo "   ✗ Only $TABLE_COUNT tables (expected 50+)"
fi
echo ""

# Cleanup
echo "9. Cleaning up..."
kubectl delete namespace $TEMP_NAMESPACE --wait=false > /dev/null 2>&1
echo ""

echo "=========================================="
if [ "$TABLE_COUNT" -gt 50 ]; then
    echo "✓✓✓ COMPLETE SUCCESS ✓✓✓"
    echo "=========================================="
    echo ""
    echo "Database ready with $TABLE_COUNT tables"
    echo ""
    echo "NEXT: Restart IQGeo application"
    echo "  ./restart-iqgeo-pods.sh"
    echo ""
    echo "Then check:"
    echo "  kubectl get pods -n iqgeo"
    echo "  kubectl logs -n iqgeo -l app=iqgeo-platform --tail=50"
else
    echo "Installation Issues"
    echo "=========================================="
    echo ""
    echo "Tables: $TABLE_COUNT (expected 50+)"
    echo ""
    echo "Check logs:"
    echo "  cat /tmp/core-final.txt | grep -i error"
    echo "  cat /tmp/comms-final.txt | grep -i error"
fi
echo ""
