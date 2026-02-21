#!/bin/bash
OUTPUT_FILE="ready-status.txt"

{
echo "========================================="
echo "Waiting for Pod to Become Ready - $(date)"
echo "========================================="
echo ""

MAX_WAIT=300  # 5 minutes
CHECK_INTERVAL=15
elapsed=0

while [ $elapsed -lt $MAX_WAIT ]; do
    echo "=== Check at ${elapsed}s / ${MAX_WAIT}s ==="
    
    POD_NAME=$(kubectl get pods -n iqgeo -l app=iqgeo-platform --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}' 2>/dev/null)
    POD_PHASE=$(kubectl get pod $POD_NAME -n iqgeo -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
    POD_READY=$(kubectl get pod $POD_NAME -n iqgeo -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
    RESTARTS=$(kubectl get pod $POD_NAME -n iqgeo -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null || echo "0")
    
    echo "Pod: $POD_NAME"
    echo "Phase: $POD_PHASE"
    echo "Ready: $POD_READY"
    echo "Restarts: $RESTARTS"
    echo ""
    
    kubectl get pods -n iqgeo
    echo ""
    
    if [ "$POD_PHASE" = "Running" ] && [ "$POD_READY" = "True" ]; then
        echo "========================================="
        echo "🎉 ✅ POD IS READY!"
        echo "========================================="
        echo ""
        
        echo "=== Service Status ==="
        kubectl get svc iqgeo-platform -n iqgeo
        echo ""
        
        echo "=== External Access ==="
        EXTERNAL_IP=$(kubectl get svc iqgeo-platform -n iqgeo -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
        if [ -n "$EXTERNAL_IP" ]; then
            echo "✅ Application accessible at: http://$EXTERNAL_IP"
        else
            echo "⏳ LoadBalancer IP not assigned yet"
            kubectl get svc iqgeo-platform -n iqgeo -o wide
        fi
        echo ""
        
        echo "=== Pod Logs (Last 20 lines) ==="
        kubectl logs $POD_NAME -n iqgeo --tail=20
        echo ""
        
        exit 0
    fi
    
    # Check if pod is crashing
    if [ "$RESTARTS" -gt 10 ]; then
        echo "========================================="
        echo "⚠️  Pod has restarted $RESTARTS times - something is wrong"
        echo "========================================="
        echo ""
        echo "=== Recent Logs ==="
        kubectl logs $POD_NAME -n iqgeo --tail=50
        echo ""
        echo "=== Pod Events ==="
        kubectl get events -n iqgeo --field-selector involvedObject.name=$POD_NAME --sort-by='.lastTimestamp' | tail -20
        exit 1
    fi
    
    echo "Status: $POD_PHASE (Ready: $POD_READY, Restarts: $RESTARTS)"
    echo "Last 10 lines of logs:"
    kubectl logs $POD_NAME -n iqgeo --tail=10 2>&1
    echo ""
    echo "Waiting $CHECK_INTERVAL seconds..."
    sleep $CHECK_INTERVAL
    elapsed=$((elapsed + CHECK_INTERVAL))
    echo ""
done

echo "========================================="
echo "⏱️  Timeout after ${MAX_WAIT} seconds"
echo "========================================="
echo ""
echo "Final status:"
kubectl get pods -n iqgeo
echo ""
echo "Pod logs:"
kubectl logs $POD_NAME -n iqgeo --tail=50 2>&1

} > "$OUTPUT_FILE" 2>&1

cat "$OUTPUT_FILE"
echo ""
echo "✅ Output saved to $OUTPUT_FILE"
