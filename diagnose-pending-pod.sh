#!/bin/bash
echo "========================================="
echo "Diagnosing Pending Pod Issue"
echo "========================================="
echo ""

POD_NAME=$(kubectl get pods -n iqgeo -l app=iqgeo-platform --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}' 2>/dev/null)

if [ -z "$POD_NAME" ]; then
    echo "❌ No pod found with label app=iqgeo-platform"
    exit 1
fi

echo "Pod: $POD_NAME"
echo ""

echo "=== 1. Pod Status ==="
kubectl get pods -n iqgeo $POD_NAME
echo ""

echo "=== 2. Pod Phase and Conditions ==="
kubectl get pod $POD_NAME -n iqgeo -o jsonpath='{.status.phase}'
echo ""
kubectl get pod $POD_NAME -n iqgeo -o jsonpath='{.status.conditions}' | python3 -m json.tool
echo ""

echo "=== 3. Init Container Status ==="
kubectl get pod $POD_NAME -n iqgeo -o jsonpath='{.status.initContainerStatuses}' | python3 -m json.tool
echo ""

echo "=== 4. Container Statuses ==="
kubectl get pod $POD_NAME -n iqgeo -o jsonpath='{.status.containerStatuses}' | python3 -m json.tool
echo ""

echo "=== 5. Recent Events ==="
kubectl get events -n iqgeo --field-selector involvedObject.name=$POD_NAME --sort-by='.lastTimestamp' | tail -20
echo ""

echo "=== 6. Full Pod Description ==="
kubectl describe pod $POD_NAME -n iqgeo | tail -50
echo ""

echo "=== 7. Checking Node Resources ==="
NODE=$(kubectl get pod $POD_NAME -n iqgeo -o jsonpath='{.spec.nodeName}')
if [ -n "$NODE" ]; then
    echo "Scheduled on node: $NODE"
    kubectl describe node $NODE | grep -A 5 "Allocated resources"
else
    echo "Pod not scheduled to any node yet"
fi
echo ""

echo "=== 8. Init Container Logs (if available) ==="
kubectl logs $POD_NAME -n iqgeo -c init-ensure-db-connection --tail=50 2>&1 || echo "Init container not started yet"
echo ""

echo "=== 9. Image Pull Progress ==="
kubectl get pod $POD_NAME -n iqgeo -o json | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    
    # Check init containers
    if 'initContainerStatuses' in data['status']:
        for ic in data['status']['initContainerStatuses']:
            print(f\"Init Container: {ic['name']}\")
            print(f\"  Image: {ic['image']}\")
            if 'state' in ic:
                if 'waiting' in ic['state']:
                    print(f\"  State: Waiting - {ic['state']['waiting'].get('reason', 'Unknown')}\")
                    if 'message' in ic['state']['waiting']:
                        print(f\"  Message: {ic['state']['waiting']['message']}\")
                elif 'running' in ic['state']:
                    print(f\"  State: Running\")
                elif 'terminated' in ic['state']:
                    print(f\"  State: Terminated - {ic['state']['terminated'].get('reason', 'Unknown')}\")
            print()
    
    # Check main containers
    if 'containerStatuses' in data['status']:
        for c in data['status']['containerStatuses']:
            print(f\"Container: {c['name']}\")
            print(f\"  Image: {c['image']}\")
            if 'state' in c:
                if 'waiting' in c['state']:
                    print(f\"  State: Waiting - {c['state']['waiting'].get('reason', 'Unknown')}\")
                elif 'running' in c['state']:
                    print(f\"  State: Running\")
            print()
except Exception as e:
    print(f'Error parsing: {e}')
"
echo ""

echo "========================================="
echo "Diagnosis Complete"
echo "========================================="
