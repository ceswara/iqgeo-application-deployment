#!/bin/bash
echo "========================================="
echo "Verifying ImagePullSecrets Configuration"
echo "========================================="

echo ""
echo "=== 1. What the deployment is configured to use ==="
kubectl get deployment iqgeo-platform -n iqgeo -o jsonpath='{.spec.template.spec.imagePullSecrets}' | python3 -m json.tool
echo ""

echo ""
echo "=== 2. Available secrets in iqgeo namespace ==="
kubectl get secrets -n iqgeo | grep harbor
echo ""

echo ""
echo "=== 3. Harbor secret contents (dockerconfigjson) ==="
kubectl get secret harbor-repository -n iqgeo -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | python3 -m json.tool
echo ""

echo ""
echo "=== 4. Testing Harbor connectivity ==="
HARBOR_USER=$(kubectl get secret harbor-repository -n iqgeo -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | python3 -c "import sys, json; print(json.load(sys.stdin)['auths']['harbor.delivery.iqgeo.cloud']['username'])")
HARBOR_PASS=$(kubectl get secret harbor-repository -n iqgeo -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | python3 -c "import sys, json; print(json.load(sys.stdin)['auths']['harbor.delivery.iqgeo.cloud']['password'])")

echo "Testing credentials..."
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" -u "$HARBOR_USER:$HARBOR_PASS" \
  https://harbor.delivery.iqgeo.cloud/v2/nmti-trials/editions-nmt-comms-cloud/manifests/7.3

echo ""
echo "========================================="
