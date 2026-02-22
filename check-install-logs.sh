#!/bin/bash
# Check the installation logs from the last attempt

echo "Checking installation pod logs..."
echo ""

# Find the most recent install namespace
INSTALL_NS=$(kubectl get ns | grep "install-bg-" | tail -1 | awk '{print $1}')

if [ -z "$INSTALL_NS" ]; then
    echo "No install namespace found"
    exit 1
fi

echo "Found namespace: $INSTALL_NS"
echo ""

echo "Installation logs from pod:"
kubectl exec -n $INSTALL_NS install -- cat /tmp/core-install.log 2>&1 | tail -100

echo ""
echo "Checking if myw_db process is still running:"
kubectl exec -n $INSTALL_NS install -- ps aux | grep myw_db || echo "Process finished"
