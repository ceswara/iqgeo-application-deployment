#!/bin/bash
# Script to reset the PostgreSQL password for the iqgeo user
# This must be run with postgres superuser access

set -e

echo "=========================================="
echo "PostgreSQL Password Reset"
echo "=========================================="
echo ""

# Configuration
DB_HOST="10.42.42.9"
DB_PORT="5432"
DB_NAME="iqgeo"
DB_USER="iqgeo"
NEW_PASSWORD="MrsIQGEO"  # Using password from working cluster

echo "Target Database Server: $DB_HOST:$DB_PORT"
echo "Database: $DB_NAME"
echo "User to reset: $DB_USER"
echo "New password: $NEW_PASSWORD"
echo ""

# Create temporary namespace
TEMP_NAMESPACE="db-reset-$(date +%s)"
echo "1. Creating temporary pod with postgres client..."
kubectl create namespace $TEMP_NAMESPACE

# Create pod with postgres client
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: db-reset
  namespace: $TEMP_NAMESPACE
spec:
  containers:
  - name: postgres
    image: postgres:16
    command: ["sleep", "600"]
    env:
    - name: PGHOST
      value: "$DB_HOST"
    - name: PGPORT
      value: "$DB_PORT"
  restartPolicy: Never
EOF

echo "   Waiting for pod to be ready..."
kubectl wait --for=condition=Ready pod/db-reset -n $TEMP_NAMESPACE --timeout=120s
echo ""

echo "2. Resetting password for user '$DB_USER'..."
echo ""
echo "   IMPORTANT: You'll be prompted for the PostgreSQL SUPERUSER password."
echo "   This is typically the 'postgres' user password on your database server."
echo ""

# Method 1: Try with postgres superuser
kubectl exec -it -n $TEMP_NAMESPACE db-reset -- psql -U postgres -d postgres -h $DB_HOST -p $DB_PORT << 'EOSQL'
-- Reset the password for iqgeo user
ALTER USER iqgeo WITH PASSWORD 'MrsIQGEO';

-- Ensure user has necessary permissions
GRANT ALL PRIVILEGES ON DATABASE iqgeo TO iqgeo;

-- Show confirmation
\du iqgeo
EOSQL

echo ""
echo "3. Testing new password..."
kubectl exec -n $TEMP_NAMESPACE db-reset -- psql -U $DB_USER -d $DB_NAME -h $DB_HOST -p $DB_PORT \
  -c "SELECT current_database(), current_user;" <<< "$NEW_PASSWORD"

echo ""
echo "4. Cleaning up..."
kubectl delete namespace $TEMP_NAMESPACE --wait=false

echo ""
echo "=========================================="
echo "Password Reset Complete"
echo "=========================================="
echo ""
echo "New password for user '$DB_USER': $NEW_PASSWORD"
echo ""
echo "Next steps:"
echo "1. Update terraform.tfvars with new password"
echo "2. Run: terraform apply"
echo "3. Run: ./initialize-database-schema.sh"
echo "4. Run: ./restart-iqgeo-pods.sh"
echo ""
