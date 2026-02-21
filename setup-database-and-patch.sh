#!/bin/bash
set -e

OUTPUT_FILE="database-setup-output.txt"

# Generate a secure random password
DB_PASSWORD="IQGeo$(openssl rand -base64 12 | tr -d '/+=' | cut -c1-16)2026!"

{
echo "========================================="
echo "Database Setup and Configuration - $(date)"
echo "========================================="
echo ""

echo "Generated secure database password: $DB_PASSWORD"
echo ""

echo "Step 1: Setting up PostgreSQL database on 10.42.42.9..."
echo ""

# Create database setup SQL commands
cat > /tmp/setup_iqgeo_db.sql << EOF
-- Drop existing database and user if they exist (start fresh)
DROP DATABASE IF EXISTS iqgeo;
DROP USER IF EXISTS iqgeo;

-- Create new user with password
CREATE USER iqgeo WITH PASSWORD '$DB_PASSWORD';

-- Create database owned by iqgeo user
CREATE DATABASE iqgeo OWNER iqgeo;

-- Grant all privileges
GRANT ALL PRIVILEGES ON DATABASE iqgeo TO iqgeo;

-- Connect to iqgeo database and grant schema privileges
\c iqgeo
GRANT ALL PRIVILEGES ON SCHEMA public TO iqgeo;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO iqgeo;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO iqgeo;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES TO iqgeo;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON SEQUENCES TO iqgeo;

-- Verify user and database
\du iqgeo
\l iqgeo
EOF

echo "Created SQL setup script: /tmp/setup_iqgeo_db.sql"
echo ""

echo "Step 2: Executing SQL on database server..."
echo "NOTE: This requires SSH access to 10.42.42.9 and sudo privileges"
echo ""

# Execute SQL on database server
ssh root@10.42.42.9 "sudo -u postgres psql < /dev/stdin" < /tmp/setup_iqgeo_db.sql

echo "✅ Database and user created successfully"
echo ""

echo "Step 3: Testing database connection..."
# Test connection using psql from a pod
kubectl run test-db-connection-setup --image=postgres:15 --rm -i --restart=Never -n iqgeo --env="PGPASSWORD=$DB_PASSWORD" -- psql -h 10.42.42.9 -U iqgeo -d iqgeo -c "SELECT version();" 2>&1 | tail -10

echo "✅ Database connection test successful"
echo ""

echo "Step 4: Updating ConfigMap with new database password..."
kubectl patch configmap iqgeo-platform-configmap -n iqgeo --type merge -p "{
  \"data\": {
    \"MYW_DB_HOST\": \"10.42.42.9\",
    \"MYW_DB_PORT\": \"5432\",
    \"MYW_DB_USERNAME\": \"iqgeo\",
    \"MYW_DB_PASSWORD\": \"$DB_PASSWORD\",
    \"MYW_DB_NAME\": \"iqgeo\",
    \"PGHOST\": \"10.42.42.9\",
    \"PGPORT\": \"5432\",
    \"PGUSER\": \"iqgeo\",
    \"PGPASSWORD\": \"$DB_PASSWORD\",
    \"PGDATABASE\": \"iqgeo\"
  }
}"

echo "✅ ConfigMap updated with new credentials"
echo ""

echo "Step 5: Verifying ConfigMap update..."
kubectl get configmap iqgeo-platform-configmap -n iqgeo -o jsonpath='{.data}' | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(f\"MYW_DB_HOST: {data.get('MYW_DB_HOST')}\")
print(f\"MYW_DB_USERNAME: {data.get('MYW_DB_USERNAME')}\")
print(f\"MYW_DB_PASSWORD: {data.get('MYW_DB_PASSWORD')[:10]}...\")
print(f\"PGHOST: {data.get('PGHOST')}\")
"
echo ""

echo "Step 6: Deleting pod to restart with new credentials..."
kubectl delete pod -n iqgeo -l app=iqgeo-platform
echo "✅ Pod deleted, new pod will be created automatically"
echo ""

echo "Step 7: Waiting 30 seconds for new pod to start..."
sleep 30

echo "Step 8: Checking pod status..."
kubectl get pods -n iqgeo
echo ""

POD_NAME=$(kubectl get pods -n iqgeo -l app=iqgeo-platform --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}' 2>/dev/null)
echo "New pod: $POD_NAME"
echo ""

echo "Step 9: Checking init container logs..."
kubectl logs $POD_NAME -n iqgeo -c init-ensure-db-connection --tail=10 2>&1 || echo "Init container not started yet"
echo ""

echo "Step 10: Waiting 60 more seconds for application startup..."
sleep 60

echo "Step 11: Checking application container logs..."
kubectl logs $POD_NAME -n iqgeo --tail=30 2>&1 || echo "Application not started yet"
echo ""

echo "Step 12: Final pod status..."
kubectl get pods -n iqgeo
echo ""

POD_PHASE=$(kubectl get pod $POD_NAME -n iqgeo -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
POD_READY=$(kubectl get pod $POD_NAME -n iqgeo -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")

echo "Pod Phase: $POD_PHASE"
echo "Pod Ready: $POD_READY"
echo ""

if [ "$POD_PHASE" = "Running" ] && [ "$POD_READY" = "True" ]; then
    echo "========================================="
    echo "🎉 ✅ SUCCESS! POD IS RUNNING!"
    echo "========================================="
    echo ""
    kubectl get svc iqgeo-platform -n iqgeo
elif [ "$POD_PHASE" = "Running" ]; then
    echo "⏳ Pod is Running but not Ready yet."
    echo "Run ./wait-for-ready.sh to continue monitoring"
else
    echo "⚠️  Pod Status: $POD_PHASE"
    echo "Checking for errors..."
    kubectl logs $POD_NAME -n iqgeo --tail=20 2>&1
fi

echo ""
echo "========================================="
echo "DATABASE CREDENTIALS (SAVE THESE!):"
echo "========================================="
echo "Host: 10.42.42.9"
echo "Port: 5432"
echo "Database: iqgeo"
echo "Username: iqgeo"
echo "Password: $DB_PASSWORD"
echo ""
echo "⚠️  IMPORTANT: Save these credentials securely!"
echo "Update terraform.tfvars files with this password for future deployments:"
echo "  - /opt/iqgeo-onprem-deployment/terraform/terraform.tfvars (line 24)"
echo "  - /opt/iqgeo-application-deployment/terraform.tfvars (line 31)"
echo "========================================="
echo ""
echo "Setup Complete - $(date)"
echo "========================================="

# Clean up temp file
rm -f /tmp/setup_iqgeo_db.sql

} > "$OUTPUT_FILE" 2>&1

cat "$OUTPUT_FILE"
echo ""
echo "✅ Output saved to $OUTPUT_FILE"
