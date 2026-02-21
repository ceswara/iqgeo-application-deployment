#!/bin/bash
# Script to restart IQGeo pods after database schema initialization
# Run this after initialize-database-schema.sh completes successfully

set -e

echo "=========================================="
echo "Restarting IQGeo Application Pods"
echo "=========================================="
echo ""

NAMESPACE="iqgeo"

# Check if namespace exists
if ! kubectl get namespace $NAMESPACE > /dev/null 2>&1; then
    echo "ERROR: Namespace '$NAMESPACE' not found"
    echo "Available namespaces:"
    kubectl get namespaces
    exit 1
fi

echo "1. Finding IQGeo deployments..."
DEPLOYMENTS=$(kubectl get deployments -n $NAMESPACE -o name 2>/dev/null | grep -i "iqgeo\|platform" || echo "")

if [ -z "$DEPLOYMENTS" ]; then
    echo "   No IQGeo deployments found in namespace $NAMESPACE"
    echo ""
    echo "   All deployments in namespace:"
    kubectl get deployments -n $NAMESPACE
    exit 1
fi

echo "   Found deployments:"
echo "$DEPLOYMENTS" | sed 's/^/     /'
echo ""

# Restart each deployment
echo "2. Restarting deployments..."
for DEPLOYMENT in $DEPLOYMENTS; do
    DEPLOY_NAME=$(echo $DEPLOYMENT | cut -d'/' -f2)
    echo "   Restarting: $DEPLOY_NAME"
    kubectl rollout restart $DEPLOYMENT -n $NAMESPACE
done
echo ""

# Also restart statefulsets if any (for Redis)
echo "3. Checking for StatefulSets..."
STATEFULSETS=$(kubectl get statefulsets -n $NAMESPACE -o name 2>/dev/null | grep -i "redis\|iqgeo" || echo "")

if [ -n "$STATEFULSETS" ]; then
    echo "   Found StatefulSets:"
    echo "$STATEFULSETS" | sed 's/^/     /'
    echo ""
    for STS in $STATEFULSETS; do
        STS_NAME=$(echo $STS | cut -d'/' -f2)
        echo "   Restarting: $STS_NAME"
        kubectl rollout restart $STS -n $NAMESPACE
    done
else
    echo "   No StatefulSets found"
fi
echo ""

# Wait for rollout to complete
echo "4. Waiting for deployments to be ready..."
for DEPLOYMENT in $DEPLOYMENTS; do
    DEPLOY_NAME=$(echo $DEPLOYMENT | cut -d'/' -f2)
    echo "   Waiting for $DEPLOY_NAME..."
    kubectl rollout status $DEPLOYMENT -n $NAMESPACE --timeout=300s || echo "   Warning: Timeout waiting for $DEPLOY_NAME"
done
echo ""

# Show current pod status
echo "5. Current pod status:"
kubectl get pods -n $NAMESPACE
echo ""

# Show recent logs from platform pods
echo "6. Recent logs from IQGeo platform:"
kubectl logs -n $NAMESPACE -l app=iqgeo-platform --tail=30 --prefix=true 2>&1 | head -50
echo ""

echo "=========================================="
echo "Restart Complete"
echo "=========================================="
echo ""
echo "Check if pods are running:"
echo "  kubectl get pods -n $NAMESPACE"
echo ""
echo "Check application logs:"
echo "  kubectl logs -n $NAMESPACE -l app=iqgeo-platform --tail=100"
echo ""
echo "If pods are still crashing, check the logs above for errors."
echo ""
