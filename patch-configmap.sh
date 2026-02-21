#!/bin/bash
set -e

OUTPUT_FILE="configmap-patch-output.txt"

{
echo "========================================="
echo "Patching ConfigMap with Correct Database Values - $(date)"
echo "========================================="
echo ""

echo "Step 1: Current ConfigMap database values..."
kubectl get configmap iqgeo-platform-configmap -n iqgeo -o jsonpath='{.data}' | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(f\"MYW_DB_HOST: '{data.get('MYW_DB_HOST', 'NOT SET')}'\")
print(f\"MYW_DB_USERNAME: '{data.get('MYW_DB_USERNAME', 'NOT SET')}'\")
print(f\"MYW_DB_PASSWORD: '{data.get('MYW_DB_PASSWORD', 'NOT SET')}'\")
print(f\"PGHOST: '{data.get('PGHOST', 'NOT SET')}'\")
print(f\"PGUSER: '{data.get('PGUSER', 'NOT SET')}'\")
print(f\"PGPASSWORD: '{data.get('PGPASSWORD', 'NOT SET')}'\")
"
echo ""

echo "Step 2: Patching ConfigMap with correct values..."
kubectl patch configmap iqgeo-platform-configmap -n iqgeo --type merge -p '{
  "data": {
    "MYW_DB_HOST": "10.42.42.9",
    "MYW_DB_PORT": "5432",
    "MYW_DB_USERNAME": "iqgeo",
    "MYW_DB_PASSWORD": "6hPfVGmi9gMMhhmE5pR64xDz4ahcQnvg",
    "MYW_DB_NAME": "iqgeo",
    "PGHOST": "10.42.42.9",
    "PGPORT": "5432",
    "PGUSER": "iqgeo",
    "PGPASSWORD": "6hPfVGmi9gMMhhmE5pR64xDz4ahcQnvg",
    "PGDATABASE": "iqgeo"
  }
}'

echo "✅ ConfigMap patched"
echo ""

echo "Step 3: Verifying patched values..."
kubectl get configmap iqgeo-platform-configmap -n iqgeo -o jsonpath='{.data}' | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(f\"MYW_DB_HOST: '{data.get('MYW_DB_HOST', 'NOT SET')}'\")
print(f\"MYW_DB_USERNAME: '{data.get('MYW_DB_USERNAME', 'NOT SET')}'\")
print(f\"PGHOST: '{data.get('PGHOST', 'NOT SET')}'\")
print(f\"PGUSER: '{data.get('PGUSER', 'NOT SET')}'\")
"
echo ""

echo "Step 4: Deleting pod to pick up new ConfigMap values..."
kubectl delete pod -n iqgeo -l app=iqgeo-platform
echo "✅ Pod deleted, new pod will be created automatically"
echo ""

echo "Step 5: Waiting 30 seconds for new pod to start..."
sleep 30

echo "Step 6: Checking new pod status..."
kubectl get pods -n iqgeo
echo ""

POD_NAME=$(kubectl get pods -n iqgeo -l app=iqgeo-platform --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}' 2>/dev/null)
echo "New pod: $POD_NAME"
echo ""

echo "Step 7: Checking init container logs..."
kubectl logs $POD_NAME -n iqgeo -c init-ensure-db-connection --tail=20 2>&1 || echo "Init container not started yet"
echo ""

echo "Step 8: Waiting another 30 seconds for DB connection..."
sleep 30

echo "Step 9: Final status check..."
kubectl get pods -n iqgeo
echo ""

POD_PHASE=$(kubectl get pod $POD_NAME -n iqgeo -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
POD_READY=$(kubectl get pod $POD_NAME -n iqgeo -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")

echo "Pod Phase: $POD_PHASE"
echo "Pod Ready: $POD_READY"
echo ""

if [ "$POD_PHASE" = "Running" ] && [ "$POD_READY" = "True" ]; then
    echo "🎉 ✅ POD IS RUNNING!"
    echo ""
    kubectl get svc iqgeo-platform -n iqgeo
elif [ "$POD_PHASE" = "Running" ]; then
    echo "⏳ Pod is Running but not Ready yet. Checking logs..."
    kubectl logs $POD_NAME -n iqgeo --tail=30 2>&1
else
    echo "⚠️  Pod Status: $POD_PHASE"
    echo "Checking init container logs..."
    kubectl logs $POD_NAME -n iqgeo -c init-ensure-db-connection --tail=30 2>&1
fi

echo ""
echo "========================================="
echo "Patch Complete - $(date)"
echo "========================================="

} > "$OUTPUT_FILE" 2>&1

cat "$OUTPUT_FILE"
echo ""
echo "✅ Output saved to $OUTPUT_FILE"
