#!/bin/bash
set -e

SCHEMA_FILE="working-db-schema.sql"
NEW_DB_HOST="10.42.42.9"
NEW_DB_USER="iqgeo"
NEW_DB_NAME="iqgeo"
NEW_DB_PASSWORD="IQGeoXHKtCMFtrPRrjV012026!"

OUTPUT_FILE="schema-import-output.txt"

{
echo "========================================="
echo "Importing Schema to New Database - $(date)"
echo "========================================="
echo ""

if [ ! -f "$SCHEMA_FILE" ]; then
    echo "❌ Error: $SCHEMA_FILE not found!"
    echo ""
    echo "Please run ./export-working-db-schema.sh first to export the schema"
    echo "from your working cluster."
    exit 1
fi

echo "Schema file: $SCHEMA_FILE"
echo "Target database: $NEW_DB_HOST/$NEW_DB_NAME"
echo ""

echo "Step 1: Copying schema file to database server..."
scp "$SCHEMA_FILE" root@$NEW_DB_HOST:/tmp/
echo "✅ Schema file copied"
echo ""

echo "Step 2: Importing schema into database..."
ssh root@$NEW_DB_HOST "PGPASSWORD='$NEW_DB_PASSWORD' psql -h localhost -U $NEW_DB_USER -d $NEW_DB_NAME -f /tmp/$SCHEMA_FILE" 2>&1

echo ""
echo "Step 3: Verifying schema import..."
TABLE_COUNT=$(ssh root@$NEW_DB_HOST "PGPASSWORD='$NEW_DB_PASSWORD' psql -h localhost -U $NEW_DB_USER -d $NEW_DB_NAME -t -c 'SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '\''public'\'';'" 2>&1 | tr -d ' ')

echo "Tables in database: $TABLE_COUNT"
echo ""

if [ "$TABLE_COUNT" -gt 0 ]; then
    echo "✅ Schema imported successfully!"
    echo ""
    
    echo "Listing tables:"
    ssh root@$NEW_DB_HOST "PGPASSWORD='$NEW_DB_PASSWORD' psql -h localhost -U $NEW_DB_USER -d $NEW_DB_NAME -c '\\dt'" 2>&1
    echo ""
    
    echo "Step 4: Restarting application pod..."
    kubectl delete pod -n iqgeo -l app=iqgeo-platform
    echo "✅ Pod restarted"
    echo ""
    
    echo "Step 5: Waiting 60 seconds for pod to start..."
    sleep 60
    
    echo "Step 6: Checking pod status..."
    kubectl get pods -n iqgeo
    echo ""
    
    POD_NAME=$(kubectl get pods -n iqgeo -l app=iqgeo-platform --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}' 2>/dev/null)
    
    echo "Step 7: Checking application logs..."
    kubectl logs $POD_NAME -n iqgeo --tail=30 2>&1
    echo ""
    
    POD_PHASE=$(kubectl get pod $POD_NAME -n iqgeo -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
    POD_READY=$(kubectl get pod $POD_NAME -n iqgeo -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
    
    echo "Pod Phase: $POD_PHASE"
    echo "Pod Ready: $POD_READY"
    echo ""
    
    if [ "$POD_PHASE" = "Running" ] && [ "$POD_READY" = "True" ]; then
        echo "========================================="
        echo "🎉 ✅ SUCCESS! APPLICATION IS RUNNING!"
        echo "========================================="
        echo ""
        kubectl get svc iqgeo-platform -n iqgeo
        echo ""
        EXTERNAL_IP=$(kubectl get svc iqgeo-platform -n iqgeo -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
        if [ -n "$EXTERNAL_IP" ]; then
            echo "Application accessible at: http://$EXTERNAL_IP"
        fi
    elif [ "$POD_PHASE" = "Running" ]; then
        echo "⏳ Pod is Running but not Ready yet."
        echo "Run ./wait-for-ready.sh to continue monitoring"
    else
        echo "⚠️  Pod Status: $POD_PHASE"
        echo "Check logs above for errors"
    fi
else
    echo "❌ Schema import failed - no tables found in database"
fi

echo ""
echo "========================================="
echo "Import Complete - $(date)"
echo "========================================="

# Cleanup
ssh root@$NEW_DB_HOST "rm -f /tmp/$SCHEMA_FILE"

} > "$OUTPUT_FILE" 2>&1

cat "$OUTPUT_FILE"
echo ""
echo "✅ Output saved to $OUTPUT_FILE"
