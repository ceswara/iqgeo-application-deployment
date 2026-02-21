#!/bin/bash
# Final deployment script with CORRECT database password
# This will initialize the database and deploy the application

set -e

echo "=========================================="
echo "IQGeo Final Deployment"
echo "=========================================="
echo ""
echo "Using VERIFIED working credentials:"
echo "  User: iqgeo"
echo "  Password: IQGeoXHKtCMFtrPRrjV012026!"
echo "  Database: iqgeo@10.42.42.9:5432"
echo ""

cd /opt/iqgeo-application-deployment
git pull
echo ""

# Step 1: Apply Terraform with correct password
echo "1. Applying Terraform with correct database password..."
terraform apply -auto-approve > terraform-final-apply.txt 2>&1
cat terraform-final-apply.txt | tail -15
echo ""

# Step 2: Initialize database schema
echo "2. Initializing database schema..."
./initialize-database-schema.sh > init-final.txt 2>&1
echo "   Output saved to init-final.txt"
echo ""
echo "   Initialization summary:"
cat init-final.txt | grep -E "✓|✗|Total tables|ERROR|SUCCESS" | tail -20
echo ""

# Step 3: Verify tables were created
echo "3. Verifying database tables..."
./verify-database-tables.sh > verify-final-v2.txt 2>&1
echo ""

TABLE_COUNT=$(grep "Total tables:" verify-final-v2.txt | awk '{print $3}' | head -1)
if [ -z "$TABLE_COUNT" ]; then
    TABLE_COUNT=0
fi

echo "   Database now has: $TABLE_COUNT tables"
echo ""

if [ "$TABLE_COUNT" -gt 50 ]; then
    echo "   ✓ Database schema initialized successfully!"
    echo ""
    
    # Step 4: Restart pods
    echo "4. Restarting IQGeo application pods..."
    ./restart-iqgeo-pods.sh > restart-final-v2.txt 2>&1
    cat restart-final-v2.txt | tail -40
    echo ""
    
    # Step 5: Wait and check status
    echo "5. Waiting 60 seconds for pods to fully start..."
    sleep 60
    echo ""
    
    echo "6. Final Pod Status:"
    kubectl get pods -n iqgeo -o wide > pod-status-final-v2.txt 2>&1
    cat pod-status-final-v2.txt
    echo ""
    
    # Check for running/crashloop pods
    RUNNING=$(kubectl get pods -n iqgeo | grep -c "Running" || echo "0")
    CRASHLOOP=$(kubectl get pods -n iqgeo | grep -c "CrashLoopBackOff\|Error" || echo "0")
    
    echo "7. Deployment Summary:"
    echo "   ✓ Running pods: $RUNNING"
    echo "   ✗ Crashing pods: $CRASHLOOP"
    echo ""
    
    if [ "$CRASHLOOP" -gt 0 ]; then
        echo "8. Checking logs for errors..."
        kubectl logs -n iqgeo -l app=iqgeo-platform --tail=100 --prefix=true > app-logs-final-v2.txt 2>&1
        cat app-logs-final-v2.txt | tail -60
        echo ""
    fi
    
    # Show service information
    echo "9. Application Access:"
    kubectl get svc -n iqgeo
    echo ""
    
    if [ "$RUNNING" -gt 0 ] && [ "$CRASHLOOP" -eq 0 ]; then
        echo "=========================================="
        echo "✓✓✓ DEPLOYMENT SUCCESSFUL! ✓✓✓"
        echo "=========================================="
        echo ""
        echo "Application is running!"
        echo ""
        echo "Access the application:"
        EXTERNAL_IP=$(kubectl get svc -n iqgeo -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
        if [ "$EXTERNAL_IP" != "pending" ] && [ -n "$EXTERNAL_IP" ]; then
            echo "  http://$EXTERNAL_IP"
        else
            echo "  kubectl port-forward -n iqgeo svc/iqgeo-platform 8080:80"
            echo "  Then open: http://localhost:8080"
        fi
    else
        echo "=========================================="
        echo "⚠ Pods Still Starting or Crashing"
        echo "=========================================="
        echo ""
        echo "Check logs: kubectl logs -n iqgeo -l app=iqgeo-platform --tail=100 -f"
    fi
else
    echo "   ✗ Database has only $TABLE_COUNT tables"
    echo "   Schema initialization failed - check init-final.txt"
fi
echo ""

# Push all outputs
echo "10. Pushing all outputs to GitHub..."
git add *.txt
git commit -m "Final deployment outputs - $(date '+%Y-%m-%d %H:%M:%S')" || echo "    (No new changes)"
git push
echo ""

echo "Deployment script complete!"
echo ""
