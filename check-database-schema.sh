#!/bin/bash
OUTPUT_FILE="database-schema-check.txt"

DB_PASSWORD="IQGeoXHKtCMFtrPRrjV012026!"

{
echo "========================================="
echo "Database Schema Check - $(date)"
echo "========================================="
echo ""

echo "Step 1: Checking current pod status..."
kubectl get pods -n iqgeo
echo ""

POD_NAME=$(kubectl get pods -n iqgeo -l app=iqgeo-platform --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}' 2>/dev/null)
echo "Current pod: $POD_NAME"
echo ""

echo "Step 2: Checking recent application logs..."
kubectl logs $POD_NAME -n iqgeo --tail=100 2>&1 | head -80
echo ""

echo "Step 3: Checking database tables on 10.42.42.9..."
ssh root@10.42.42.9 "PGPASSWORD='$DB_PASSWORD' psql -h localhost -U iqgeo -d iqgeo -c '\\dt'" 2>&1
echo ""

echo "Step 4: Checking if database has any tables..."
TABLE_COUNT=$(ssh root@10.42.42.9 "PGPASSWORD='$DB_PASSWORD' psql -h localhost -U iqgeo -d iqgeo -t -c 'SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '\''public'\'';'" 2>&1 | tr -d ' ')
echo "Number of tables in database: $TABLE_COUNT"
echo ""

if [ "$TABLE_COUNT" = "0" ] || [ -z "$TABLE_COUNT" ]; then
    echo "⚠️  Database is empty - no tables created yet"
    echo ""
    echo "The application is trying to initialize the schema but failing."
    echo "Checking if there's an SQL initialization script in the container..."
    echo ""
    
    kubectl exec $POD_NAME -n iqgeo -- ls -la /opt/iqgeo/platform/ 2>&1 | grep -i "sql\|schema\|init" || echo "No obvious SQL files found"
    echo ""
    
    echo "Checking entrypoint scripts..."
    kubectl exec $POD_NAME -n iqgeo -- ls -la /docker-entrypoint.d/ 2>&1 || echo "No entrypoint.d directory"
    echo ""
else
    echo "✅ Database has $TABLE_COUNT tables"
    echo ""
    echo "Listing tables:"
    ssh root@10.42.42.9 "PGPASSWORD='$DB_PASSWORD' psql -h localhost -U iqgeo -d iqgeo -c '\\dt'" 2>&1
fi

echo ""
echo "Step 5: Checking ConfigMap for any schema/init settings..."
kubectl get configmap iqgeo-platform-configmap -n iqgeo -o yaml | grep -i "init\|schema\|migrate" || echo "No schema-related config found"
echo ""

echo "Step 6: Checking pod events for more clues..."
kubectl get events -n iqgeo --field-selector involvedObject.name=$POD_NAME --sort-by='.lastTimestamp' 2>&1 | tail -10
echo ""

echo "========================================="
echo "SUMMARY"
echo "========================================="
echo ""

if [ "$TABLE_COUNT" = "0" ] || [ -z "$TABLE_COUNT" ]; then
    echo "❌ Database is empty - schema not initialized"
    echo ""
    echo "NEXT STEPS:"
    echo "1. Check if the application requires manual schema initialization"
    echo "2. Look for SQL migration scripts or schema.sql files"
    echo "3. The 'setting' table error suggests the application expects a pre-populated database"
    echo ""
    echo "You may need to:"
    echo "  - Import an initial database schema"
    echo "  - Run database migrations manually"
    echo "  - Check IQGeo documentation for database setup requirements"
else
    echo "✅ Database has tables - checking why 'setting' table is missing..."
    echo ""
    echo "Run: ssh root@10.42.42.9 \"PGPASSWORD='$DB_PASSWORD' psql -h localhost -U iqgeo -d iqgeo -c '\\dt'\""
    echo "to see all tables and verify if 'setting' table exists"
fi

echo ""
echo "========================================="
echo "Check Complete - $(date)"
echo "========================================="

} > "$OUTPUT_FILE" 2>&1

cat "$OUTPUT_FILE"
echo ""
echo "✅ Output saved to $OUTPUT_FILE"
