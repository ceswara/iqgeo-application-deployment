#!/bin/bash
# Script to verify database tables, restart pods, and push outputs to GitHub

set -e

echo "=========================================="
echo "IQGeo Database Verification & Pod Restart"
echo "=========================================="
echo ""

cd /opt/iqgeo-application-deployment

# Pull latest changes
echo "1. Pulling latest changes from GitHub..."
git pull
echo ""

# Verify database tables
echo "2. Verifying database tables..."
./verify-database-tables.sh > verify-after-init.txt 2>&1
echo "   Output saved to verify-after-init.txt"
echo ""

# Show verification results
echo "3. Verification Results:"
cat verify-after-init.txt | tail -30
echo ""

# Check if tables exist before restarting
TABLE_COUNT=$(grep "Total tables:" verify-after-init.txt | awk '{print $3}' || echo "0")
if [ -z "$TABLE_COUNT" ] || [ "$TABLE_COUNT" = "" ]; then
    TABLE_COUNT=0
fi

if [ "$TABLE_COUNT" -gt 10 ]; then
    echo "   ✓ Database has $TABLE_COUNT tables - proceeding with pod restart"
    echo ""
    
    # Restart pods
    echo "4. Restarting IQGeo pods..."
    ./restart-iqgeo-pods.sh > restart-output.txt 2>&1
    echo "   Output saved to restart-output.txt"
    echo ""
    
    # Show restart results
    echo "5. Restart Results:"
    cat restart-output.txt | tail -40
    echo ""
    
    # Wait a bit for pods to stabilize
    echo "6. Waiting 30 seconds for pods to stabilize..."
    sleep 30
    
    # Get current pod status
    echo "7. Current Pod Status:"
    kubectl get pods -n iqgeo > pod-status-after-restart.txt 2>&1
    cat pod-status-after-restart.txt
    echo ""
    
    # Get recent logs
    echo "8. Recent Application Logs:"
    kubectl logs -n iqgeo -l app=iqgeo-platform --tail=50 --prefix=true > app-logs-after-restart.txt 2>&1 || echo "   (No logs available yet)"
    cat app-logs-after-restart.txt | tail -30
    echo ""
else
    echo "   ✗ Database still has $TABLE_COUNT tables - NOT restarting pods"
    echo "   Database initialization may have failed. Check verify-after-init.txt"
    echo ""
fi

# Push all outputs to GitHub
echo "9. Pushing outputs to GitHub..."
git add *.txt
git commit -m "Database verification and pod restart outputs - $(date '+%Y-%m-%d %H:%M:%S')" || echo "   (No new changes to commit)"
git push
echo ""

echo "=========================================="
echo "Complete!"
echo "=========================================="
echo ""

if [ "$TABLE_COUNT" -gt 10 ]; then
    echo "✓ Database initialized: $TABLE_COUNT tables"
    echo "✓ Pods restarted"
    echo ""
    echo "Check pod status:"
    echo "  kubectl get pods -n iqgeo"
    echo ""
    echo "Check application logs:"
    echo "  kubectl logs -n iqgeo -l app=iqgeo-platform --tail=100 -f"
else
    echo "✗ Database initialization incomplete: $TABLE_COUNT tables"
    echo ""
    echo "Please check verify-after-init.txt for errors"
fi
echo ""
