#!/bin/bash
# Script to check what upgrade versions are available in the IQGeo container

set -e

echo "=========================================="
echo "Checking Available IQGeo Upgrade Versions"
echo "=========================================="
echo ""

NAMESPACE="iqgeo"
IMAGE="harbor.delivery.iqgeo.cloud/nmti-trials/editions-nmt-comms-cloud:7.3"

# Create temporary namespace
TEMP_NAMESPACE="version-check-$(date +%s)"
echo "1. Creating temporary pod..."
kubectl create namespace $TEMP_NAMESPACE

# Copy harbor secret
kubectl get secret harbor-repository -n $NAMESPACE -o yaml 2>/dev/null | \
  sed "s/namespace: $NAMESPACE/namespace: $TEMP_NAMESPACE/" | \
  kubectl apply -f -

# Create pod
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: version-check
  namespace: $TEMP_NAMESPACE
spec:
  containers:
  - name: iqgeo
    image: $IMAGE
    command: ["sleep", "600"]
  imagePullSecrets:
  - name: harbor-repository
  restartPolicy: Never
EOF

echo "   Waiting for pod to be ready..."
kubectl wait --for=condition=Ready pod/version-check -n $TEMP_NAMESPACE --timeout=180s
echo ""

echo "2. Checking myw_db tool help..."
kubectl exec -n $TEMP_NAMESPACE version-check -- myw_db --help 2>&1 | head -50
echo ""

echo "3. Looking for available upgrade scripts in container..."
echo "   Checking for core upgrade modules:"
kubectl exec -n $TEMP_NAMESPACE version-check -- find /opt/iqgeo -name "*myw_db_upgrade*" -type f 2>/dev/null | head -20
echo ""

echo "4. Checking Python modules for upgrade versions:"
kubectl exec -n $TEMP_NAMESPACE version-check -- ls -la /opt/iqgeo/platform/WebApps/myworldapp/core/server/base/db_schema/ 2>/dev/null | grep upgrade
echo ""

echo "5. Checking comms upgrade modules:"
kubectl exec -n $TEMP_NAMESPACE version-check -- ls -la /opt/iqgeo/platform/WebApps/comms/ 2>/dev/null | grep -i upgrade || echo "   (checking subdirectories...)"
kubectl exec -n $TEMP_NAMESPACE version-check -- find /opt/iqgeo/platform/WebApps/comms -name "*upgrade*" -type f 2>/dev/null | head -20
echo ""

echo "6. Checking IQGeo version information:"
kubectl exec -n $TEMP_NAMESPACE version-check -- cat /opt/iqgeo/platform/version.txt 2>/dev/null || echo "   (version.txt not found)"
kubectl exec -n $TEMP_NAMESPACE version-check -- cat /opt/iqgeo/platform/VERSION 2>/dev/null || echo "   (VERSION file not found)"
echo ""

echo "7. Try running myw_db with database name to see available commands:"
kubectl exec -n $TEMP_NAMESPACE version-check -- bash -c "export MYW_DB_HOST=10.42.42.9 MYW_DB_PORT=5432 MYW_DB_NAME=iqgeo MYW_DB_USERNAME=iqgeo MYW_DB_PASSWORD=MrsIQGEO && myw_db iqgeo 2>&1" | head -50
echo ""

echo "8. Cleaning up..."
kubectl delete namespace $TEMP_NAMESPACE --wait=false

echo ""
echo "=========================================="
echo "Version Check Complete"
echo "=========================================="
echo ""
