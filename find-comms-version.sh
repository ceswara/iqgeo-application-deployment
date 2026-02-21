#!/bin/bash
# Script to find the correct comms upgrade version

set -e

echo "=========================================="
echo "Finding Comms Upgrade Version"
echo "=========================================="
echo ""

NAMESPACE="iqgeo"
IMAGE="harbor.delivery.iqgeo.cloud/nmti-trials/editions-nmt-comms-cloud:7.3"

# Create temporary namespace
TEMP_NAMESPACE="comms-check-$(date +%s)"
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
  name: comms-check
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
kubectl wait --for=condition=Ready pod/comms-check -n $TEMP_NAMESPACE --timeout=180s
echo ""

echo "2. Searching entire container for comms upgrade files..."
kubectl exec -n $TEMP_NAMESPACE comms-check -- find /opt/iqgeo -name "*comms*upgrade*" -o -name "*nmt*upgrade*" 2>/dev/null | grep -i upgrade
echo ""

echo "3. Checking WebApps directory structure..."
kubectl exec -n $TEMP_NAMESPACE comms-check -- ls -la /opt/iqgeo/platform/WebApps/ 2>/dev/null
echo ""

echo "4. If 'comms' directory exists, check it:"
kubectl exec -n $TEMP_NAMESPACE comms-check -- ls -la /opt/iqgeo/platform/WebApps/comms/ 2>/dev/null || echo "   (comms directory not found)"
echo ""

echo "5. Check for edition-specific upgrade modules:"
kubectl exec -n $TEMP_NAMESPACE comms-check -- find /opt/iqgeo/platform/WebApps -type d -name "*db_schema*" 2>/dev/null
echo ""

echo "6. List all upgrade modules across all WebApps:"
kubectl exec -n $TEMP_NAMESPACE comms-check -- find /opt/iqgeo/platform/WebApps -name "*upgrade*.so" 2>/dev/null
echo ""

echo "7. Try to run upgrade with 'nmt' or 'comms' to see error message:"
kubectl exec -n $TEMP_NAMESPACE comms-check -- bash -c "export MYW_DB_HOST=10.42.42.9 MYW_DB_PORT=5432 MYW_DB_NAME=iqgeo MYW_DB_USERNAME=iqgeo MYW_DB_PASSWORD=MrsIQGEO && myw_db iqgeo upgrade nmt 2>&1" || echo ""
echo ""

echo "8. Cleaning up..."
kubectl delete namespace $TEMP_NAMESPACE --wait=false

echo ""
echo "=========================================="
echo "Search Complete"
echo "=========================================="
echo ""
