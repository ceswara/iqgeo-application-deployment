#!/bin/bash
set -e

echo "========================================="
echo "Harbor Credentials Fix Script"
echo "========================================="
echo ""

# Harbor credentials
HARBOR_SERVER="harbor.delivery.iqgeo.cloud"
HARBOR_USERNAME="robot\$techwave"
HARBOR_PASSWORD="6hPfVGmi9gMMhhmE5pR64xDz4ahcQnvg"

echo "Step 1: Checking current Harbor secret status..."
echo ""
echo "=== Current secret in iqgeo namespace ==="
kubectl get secret harbor-repository -n iqgeo -o jsonpath='{.data.\.dockerconfigjson}' 2>/dev/null | base64 -d | python3 -m json.tool || echo "Secret not found or invalid"
echo ""

echo "Step 2: Testing current credentials..."
CURRENT_USER=$(kubectl get secret harbor-repository -n iqgeo -o jsonpath='{.data.\.dockerconfigjson}' 2>/dev/null | base64 -d | python3 -c "import sys, json; print(json.load(sys.stdin)['auths']['harbor.delivery.iqgeo.cloud']['username'])" 2>/dev/null || echo "unknown")
CURRENT_PASS=$(kubectl get secret harbor-repository -n iqgeo -o jsonpath='{.data.\.dockerconfigjson}' 2>/dev/null | base64 -d | python3 -c "import sys, json; print(json.load(sys.stdin)['auths']['harbor.delivery.iqgeo.cloud']['password'])" 2>/dev/null || echo "unknown")

echo "Current username: $CURRENT_USER"
echo "Expected username: robot\$techwave"
echo ""

if [ "$CURRENT_USER" = "robot\$techwave" ]; then
    echo "✅ Credentials are already correct!"
    echo ""
    echo "Testing Harbor connectivity..."
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -u "$CURRENT_USER:$CURRENT_PASS" \
      https://harbor.delivery.iqgeo.cloud/v2/nmti-trials/editions-nmt-comms-cloud/manifests/7.3)
    echo "HTTP Status: $HTTP_CODE"
    
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "307" ]; then
        echo "✅ Harbor authentication successful!"
        echo ""
        echo "Credentials are correct. Issue might be elsewhere."
        echo "Checking pod status..."
        kubectl get pods -n iqgeo
        exit 0
    else
        echo "❌ Harbor authentication failed with status: $HTTP_CODE"
        echo "Recreating secret anyway..."
    fi
else
    echo "❌ Credentials are incorrect!"
    echo ""
fi

echo "Step 3: Deleting old Harbor secrets..."
kubectl delete secret harbor-repository -n iqgeo 2>/dev/null || echo "Secret not found in iqgeo namespace"
kubectl delete secret harbor-repository -n default 2>/dev/null || echo "Secret not found in default namespace"
echo ""

echo "Step 4: Creating new Harbor secrets with correct credentials..."
kubectl create secret docker-registry harbor-repository \
  --docker-server="$HARBOR_SERVER" \
  --docker-username="$HARBOR_USERNAME" \
  --docker-password="$HARBOR_PASSWORD" \
  -n iqgeo

kubectl create secret docker-registry harbor-repository \
  --docker-server="$HARBOR_SERVER" \
  --docker-username="$HARBOR_USERNAME" \
  --docker-password="$HARBOR_PASSWORD" \
  -n default

echo "✅ Secrets created"
echo ""

echo "Step 5: Verifying new credentials..."
NEW_USER=$(kubectl get secret harbor-repository -n iqgeo -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | python3 -c "import sys, json; print(json.load(sys.stdin)['auths']['harbor.delivery.iqgeo.cloud']['username'])")
echo "New username: $NEW_USER"

echo ""
echo "Step 6: Testing Harbor connectivity with new credentials..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -u "$HARBOR_USERNAME:$HARBOR_PASSWORD" \
  https://harbor.delivery.iqgeo.cloud/v2/nmti-trials/editions-nmt-comms-cloud/manifests/7.3)
echo "HTTP Status: $HTTP_CODE"

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "307" ]; then
    echo "✅ Harbor authentication successful!"
else
    echo "❌ Harbor authentication failed with status: $HTTP_CODE"
    echo "This may indicate a network issue or incorrect credentials."
fi
echo ""

echo "Step 7: Restarting IQGeo pods to pick up new secret..."
kubectl delete pod -n iqgeo -l app=iqgeo-platform
echo "Waiting 30 seconds for new pods to start..."
sleep 30
echo ""

echo "Step 8: Checking pod status..."
kubectl get pods -n iqgeo
echo ""

echo "Step 9: Checking for image pull errors..."
kubectl get pods -n iqgeo -o json | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data.get('items', []):
    name = item['metadata']['name']
    status = item['status']
    if 'containerStatuses' in status:
        for cs in status['containerStatuses']:
            if 'waiting' in cs.get('state', {}):
                reason = cs['state']['waiting'].get('reason', '')
                if 'Image' in reason or 'Pull' in reason:
                    print(f'❌ Pod {name}: {reason}')
                    if 'message' in cs['state']['waiting']:
                        print(f'   Message: {cs[\"state\"][\"waiting\"][\"message\"]}')
    if 'initContainerStatuses' in status:
        for ics in status['initContainerStatuses']:
            if 'waiting' in ics.get('state', {}):
                reason = ics['state']['waiting'].get('reason', '')
                if 'Image' in reason or 'Pull' in reason:
                    print(f'❌ Pod {name} (init): {reason}')
                    if 'message' in ics['state']['waiting']:
                        print(f'   Message: {ics[\"state\"][\"waiting\"][\"message\"]}')
" || echo "No image pull errors found or Python parsing failed"

echo ""
echo "========================================="
echo "Fix Complete!"
echo "========================================="
echo ""
echo "Run full validation:"
echo "  ./deploy-and-validate.sh"
echo ""
