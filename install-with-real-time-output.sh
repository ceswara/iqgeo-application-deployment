#!/bin/bash
# Run installation with real-time output to catch errors

set -e

echo "=========================================="
echo "Real-Time Installation"
echo "=========================================="
echo ""

NAMESPACE="iqgeo"
DB_HOST="10.42.42.9"
DB_PORT="5432"
DB_NAME="iqgeo"
DB_USER="iqgeo"
DB_PASSWORD="IQGeoXHKtCMFtrPRrjV012026!"
IMAGE="harbor.delivery.iqgeo.cloud/nmti-trials/editions-nmt-comms-cloud:7.3"

# Create temporary namespace
TEMP_NAMESPACE="install-rt-$(date +%s)"
echo "1. Creating installation pod..."
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
    command: ["sleep", "3600"]
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

echo "2. Testing connection..."
kubectl exec -n $TEMP_NAMESPACE install -- psql -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>&1 | head -5
echo ""

echo "3. Installing CORE schema (watch for errors)..."
echo "   ================================================"
kubectl exec -n $TEMP_NAMESPACE install -- /opt/iqgeo/platform/Tools/myw_db $DB_NAME install core

CORE_EXIT=$?
echo "   ================================================"
echo "   Core exit code: $CORE_EXIT"
echo ""

echo "4. Checking tables after core installation..."
TABLE_COUNT=$(kubectl exec -n $TEMP_NAMESPACE install -- psql -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>&1 | xargs)
echo "   Tables now: $TABLE_COUNT"
echo ""

if [ "$TABLE_COUNT" -gt 30 ]; then
    echo "   ✓ Core installed successfully!"
    echo ""
    echo "5. Installing COMMS schema..."
    echo "   ================================================"
    kubectl exec -n $TEMP_NAMESPACE install -- /opt/iqgeo/platform/Tools/myw_db $DB_NAME install comms
    
    COMMS_EXIT=$?
    echo "   ================================================"
    echo "   Comms exit code: $COMMS_EXIT"
    echo ""
    
    TABLE_COUNT=$(kubectl exec -n $TEMP_NAMESPACE install -- psql -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>&1 | xargs)
    echo "   Final table count: $TABLE_COUNT"
else
    echo "   ✗ Core installation failed - only $TABLE_COUNT tables"
    echo ""
    echo "   Checking for critical tables:"
    kubectl exec -n $TEMP_NAMESPACE install -- psql -c "\dt" 2>&1 | head -20
fi
echo ""

kubectl delete namespace $TEMP_NAMESPACE --wait=false > /dev/null 2>&1

echo "=========================================="
if [ "$TABLE_COUNT" -gt 50 ]; then
    echo "✓ SUCCESS - $TABLE_COUNT tables"
    echo ""
    echo "Next: ./restart-iqgeo-pods.sh"
else
    echo "✗ FAILED - only $TABLE_COUNT tables"
fi
echo "=========================================="
