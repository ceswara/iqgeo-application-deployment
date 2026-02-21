#!/bin/bash
# Script to test the correct myw_db command syntax

set -e

echo "=========================================="
echo "Testing myw_db Command Syntax"
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
TEMP_NAMESPACE="syntax-test-$(date +%s)"
echo "1. Creating temporary pod..."
kubectl create namespace $TEMP_NAMESPACE > /dev/null 2>&1

kubectl get secret harbor-repository -n $NAMESPACE -o yaml 2>/dev/null | \
  sed "s/namespace: $NAMESPACE/namespace: $TEMP_NAMESPACE/" | \
  kubectl apply -f - > /dev/null 2>&1

cat <<EOF | kubectl apply -f - > /dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: syntax-test
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
  imagePullSecrets:
  - name: harbor-repository
  restartPolicy: Never
EOF

kubectl wait --for=condition=Ready pod/syntax-test -n $TEMP_NAMESPACE --timeout=180s > /dev/null 2>&1
echo "   Pod ready"
echo ""

# Test different command syntaxes
echo "2. Testing 'install' command syntax..."
echo ""

echo "   Test A: myw_db $DB_NAME install"
kubectl exec -n $TEMP_NAMESPACE syntax-test -- /opt/iqgeo/platform/Tools/myw_db $DB_NAME install 2>&1 | head -20
echo ""

echo "   Test B: myw_db $DB_NAME install --help"
kubectl exec -n $TEMP_NAMESPACE syntax-test -- /opt/iqgeo/platform/Tools/myw_db $DB_NAME install --help 2>&1 | head -30
echo ""

echo "3. Testing 'upgrade' command syntax..."
echo ""

echo "   Test C: myw_db $DB_NAME upgrade --help"
kubectl exec -n $TEMP_NAMESPACE syntax-test -- /opt/iqgeo/platform/Tools/myw_db $DB_NAME upgrade --help 2>&1 | head -30
echo ""

echo "   Test D: myw_db $DB_NAME upgrade core"
kubectl exec -n $TEMP_NAMESPACE syntax-test -- /opt/iqgeo/platform/Tools/myw_db $DB_NAME upgrade core 2>&1 | head -20
echo ""

echo "   Test E: myw_db $DB_NAME upgrade comms"
kubectl exec -n $TEMP_NAMESPACE syntax-test -- /opt/iqgeo/platform/Tools/myw_db $DB_NAME upgrade comms 2>&1 | head -20
echo ""

echo "4. Cleaning up..."
kubectl delete namespace $TEMP_NAMESPACE --wait=false > /dev/null 2>&1

echo ""
echo "=========================================="
echo "Syntax Test Complete"
echo "=========================================="
echo ""
