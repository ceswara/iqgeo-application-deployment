#!/bin/bash
# Complete deployment fix: apply Terraform, verify database, restart pods, push outputs

set -e

echo "=========================================="
echo "IQGeo Complete Deployment Fix"
echo "=========================================="
echo ""

cd /opt/iqgeo-application-deployment

# Pull latest changes
echo "1. Pulling latest changes from GitHub..."
git pull
echo ""

# Apply Terraform to fix ConfigMap with correct password
echo "2. Applying Terraform to update Helm values..."
echo "   This will update the ConfigMap with correct database credentials:"
echo "   - User: iqgeo (not postgres)"
echo "   - Password: MrsIQGEO (not iqgeo)"
echo ""
terraform apply -auto-approve > terraform-apply-output.txt 2>&1
echo "   Output saved to terraform-apply-output.txt"
cat terraform-apply-output.txt | tail -20
echo ""

# Wait for Helm to update ConfigMap
echo "3. Waiting 10 seconds for Helm to update ConfigMap..."
sleep 10
echo ""

# Verify ConfigMap was updated
echo "4. Verifying ConfigMap has correct password..."
CONFIGMAP_PASSWORD=$(kubectl get configmap -n iqgeo -o yaml | grep "MYW_DB_PASSWORD:" | awk '{print $2}' | head -1)
echo "   ConfigMap MYW_DB_PASSWORD: $CONFIGMAP_PASSWORD"
if [ "$CONFIGMAP_PASSWORD" = "MrsIQGEO" ]; then
    echo "   ✓ ConfigMap password is correct"
else
    echo "   ✗ ConfigMap password is still wrong: $CONFIGMAP_PASSWORD"
    echo "   Expected: MrsIQGEO"
fi
echo ""

# Verify database tables
echo "5. Verifying database tables..."
./verify-database-tables.sh > verify-final.txt 2>&1
echo "   Output saved to verify-final.txt"
echo ""

# Show verification results
echo "6. Verification Results:"
cat verify-final.txt | tail -35
echo ""

# Check if tables exist
TABLE_COUNT=$(grep "Total tables:" verify-final.txt | awk '{print $3}' || echo "0")
if [ -z "$TABLE_COUNT" ] || [ "$TABLE_COUNT" = "" ]; then
    TABLE_COUNT=0
fi

echo "   Database has $TABLE_COUNT tables"
echo ""

if [ "$TABLE_COUNT" -gt 10 ]; then
    echo "   ✓ Database schema is initialized - proceeding with pod restart"
    echo ""
    
    # Restart pods
    echo "7. Restarting IQGeo pods..."
    ./restart-iqgeo-pods.sh > restart-final.txt 2>&1
    echo "   Output saved to restart-final.txt"
    echo ""
    
    # Show restart results
    echo "8. Restart Results:"
    cat restart-final.txt | tail -50
    echo ""
    
    # Wait for pods to stabilize
    echo "9. Waiting 45 seconds for pods to fully start..."
    sleep 45
    
    # Get final pod status
    echo "10. Final Pod Status:"
    kubectl get pods -n iqgeo > pod-status-final.txt 2>&1
    cat pod-status-final.txt
    echo ""
    
    # Get application logs
    echo "11. Application Logs (checking for errors):"
    kubectl logs -n iqgeo -l app=iqgeo-platform --tail=80 --prefix=true > app-logs-final.txt 2>&1 || echo "   (No logs available yet)"
    cat app-logs-final.txt | tail -50
    echo ""
    
    # Check if pods are running
    RUNNING_PODS=$(kubectl get pods -n iqgeo | grep -c "Running" || echo "0")
    CRASHLOOP_PODS=$(kubectl get pods -n iqgeo | grep -c "CrashLoopBackOff\|Error" || echo "0")
    
    echo "12. Deployment Status:"
    echo "   Running pods: $RUNNING_PODS"
    echo "   Crashing pods: $CRASHLOOP_PODS"
    echo ""
    
    if [ "$RUNNING_PODS" -gt 0 ] && [ "$CRASHLOOP_PODS" -eq 0 ]; then
        echo "   ✓✓✓ SUCCESS! IQGeo application is running!"
    elif [ "$CRASHLOOP_PODS" -gt 0 ]; then
        echo "   ⚠ Some pods are still crashing - check app-logs-final.txt"
    else
        echo "   ⏳ Pods are still starting - check status in a few minutes"
    fi
else
    echo "   ✗ Database has only $TABLE_COUNT tables - schema initialization likely failed"
    echo "   NOT restarting pods until database is properly initialized"
    echo ""
    echo "   Check verify-final.txt for database connection errors"
fi
echo ""

# Push all outputs to GitHub
echo "13. Pushing all outputs to GitHub..."
git add *.txt
git commit -m "Full deployment fix outputs - $(date '+%Y-%m-%d %H:%M:%S')" || echo "   (No new changes to commit)"
git push
echo ""

echo "=========================================="
echo "Complete!"
echo "=========================================="
echo ""

if [ "$TABLE_COUNT" -gt 10 ]; then
    echo "Next steps:"
    echo "1. Check if pods are running: kubectl get pods -n iqgeo"
    echo "2. Check logs: kubectl logs -n iqgeo -l app=iqgeo-platform --tail=100 -f"
    echo "3. Access application: kubectl get svc -n iqgeo"
else
    echo "Database issue detected. Please check verify-final.txt"
fi
echo ""
