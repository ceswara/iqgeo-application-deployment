#!/bin/bash
echo "========================================="
echo "Monitoring IQGeo Pod Startup"
echo "========================================="
echo ""

MAX_WAIT=300  # 5 minutes
INTERVAL=10
elapsed=0

while [ $elapsed -lt $MAX_WAIT ]; do
    echo "=== Time: ${elapsed}s / ${MAX_WAIT}s ==="
    echo ""
    
    # Get pod status
    POD_STATUS=$(kubectl get pods -n iqgeo -l app=iqgeo-platform -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
    POD_NAME=$(kubectl get pods -n iqgeo -l app=iqgeo-platform -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "unknown")
    
    echo "Pod: $POD_NAME"
    echo "Status: $POD_STATUS"
    
    # Get detailed status
    kubectl get pods -n iqgeo -l app=iqgeo-platform
    echo ""
    
    # Check for errors
    if kubectl get pods -n iqgeo -l app=iqgeo-platform -o jsonpath='{.items[0].status.containerStatuses[0].state.waiting.reason}' 2>/dev/null | grep -q "Error\|BackOff"; then
        echo "❌ Pod encountered an error!"
        echo ""
        echo "Recent events:"
        kubectl get events -n iqgeo --sort-by='.lastTimestamp' --field-selector involvedObject.name=$POD_NAME | tail -10
        echo ""
        echo "Pod logs:"
        kubectl logs -n iqgeo $POD_NAME --all-containers=true --tail=50 2>&1
        exit 1
    fi
    
    # Check if running
    if [ "$POD_STATUS" = "Running" ]; then
        READY=$(kubectl get pods -n iqgeo -l app=iqgeo-platform -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null)
        if [ "$READY" = "true" ]; then
            echo ""
            echo "========================================="
            echo "✅ Pod is Running and Ready!"
            echo "========================================="
            echo ""
            kubectl get pods -n iqgeo
            echo ""
            kubectl get svc -n iqgeo
            echo ""
            exit 0
        else
            echo "Pod is Running but not Ready yet..."
        fi
    elif [ "$POD_STATUS" = "Pending" ]; then
        # Get init container status
        INIT_STATUS=$(kubectl get pods -n iqgeo -l app=iqgeo-platform -o jsonpath='{.items[0].status.initContainerStatuses[0].state}' 2>/dev/null)
        echo "Init container: $INIT_STATUS"
    fi
    
    echo ""
    echo "Waiting $INTERVAL seconds..."
    sleep $INTERVAL
    elapsed=$((elapsed + INTERVAL))
    echo "========================================="
    echo ""
done

echo "⏱️ Timeout reached after ${MAX_WAIT}s"
echo ""
echo "Final status:"
kubectl get pods -n iqgeo -l app=iqgeo-platform
echo ""
echo "Recent events:"
kubectl get events -n iqgeo --sort-by='.lastTimestamp' | tail -20
