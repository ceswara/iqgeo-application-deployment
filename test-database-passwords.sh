#!/bin/bash
# Script to test which password actually works on the database server

set -e

echo "=========================================="
echo "Testing Database Passwords"
echo "=========================================="
echo ""

DB_HOST="10.42.42.9"
DB_PORT="5432"
DB_NAME="iqgeo"

# Passwords to test (from various sources)
PASSWORDS=(
    "MrsIQGEO"                              # From working cluster dump
    "iqgeo"                                  # From current ConfigMap
    "6hPfVGmi9gMMhhmE5pR64xDz4ahcQnvg"      # From original terraform.tfvars
    "IQGeoXHKtCMFtrPRrjV012026!"            # From ConfigMap earlier
)

USERS=("iqgeo" "postgres")

# Create temporary namespace
TEMP_NAMESPACE="pw-test-$(date +%s)"
echo "1. Creating temporary test pod..."
kubectl create namespace $TEMP_NAMESPACE > /dev/null 2>&1

cat <<EOF | kubectl apply -f - > /dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: pw-test
  namespace: $TEMP_NAMESPACE
spec:
  containers:
  - name: postgres
    image: postgres:16
    command: ["sleep", "300"]
  restartPolicy: Never
EOF

kubectl wait --for=condition=Ready pod/pw-test -n $TEMP_NAMESPACE --timeout=120s > /dev/null 2>&1
echo "   Pod ready"
echo ""

echo "2. Testing password combinations..."
echo ""

for USER in "${USERS[@]}"; do
    echo "Testing user: $USER"
    for i in "${!PASSWORDS[@]}"; do
        PASSWORD="${PASSWORDS[$i]}"
        PASSWORD_LABEL="Password $((i+1))"
        
        # Truncate password for display
        if [ ${#PASSWORD} -gt 20 ]; then
            DISPLAY_PW="${PASSWORD:0:17}..."
        else
            DISPLAY_PW="$PASSWORD"
        fi
        
        echo -n "   $PASSWORD_LABEL ($DISPLAY_PW): "
        
        # Test connection
        if kubectl exec -n $TEMP_NAMESPACE pw-test -- bash -c \
          "PGPASSWORD='$PASSWORD' psql -h $DB_HOST -p $DB_PORT -U $USER -d $DB_NAME -c 'SELECT 1;' > /dev/null 2>&1"; then
            echo "✓ SUCCESS!"
            echo ""
            echo "   ================================================"
            echo "   WORKING CREDENTIALS FOUND:"
            echo "   ================================================"
            echo "   User: $USER"
            echo "   Password: $PASSWORD"
            echo "   Host: $DB_HOST:$DB_PORT"
            echo "   Database: $DB_NAME"
            echo "   ================================================"
            echo ""
            
            # Save to file
            cat > WORKING-DATABASE-CREDENTIALS.txt <<EOCRED
Working Database Credentials
=============================

Host: $DB_HOST
Port: $DB_PORT
Database: $DB_NAME
User: $USER
Password: $PASSWORD

This was tested and confirmed working on $(date)
EOCRED
            
            # Cleanup
            kubectl delete namespace $TEMP_NAMESPACE --wait=false > /dev/null 2>&1
            exit 0
        else
            echo "✗ Failed"
        fi
    done
    echo ""
done

# Cleanup
echo "3. Cleaning up..."
kubectl delete namespace $TEMP_NAMESPACE --wait=false > /dev/null 2>&1
echo ""

echo "=========================================="
echo "No Working Password Found!"
echo "=========================================="
echo ""
echo "None of the known passwords work with the database server."
echo ""
echo "You need to:"
echo "1. Check what password is actually set on PostgreSQL server 10.42.42.9"
echo "2. Or reset it using the database server's admin console"
echo "3. Then update terraform.tfvars with the correct password"
echo ""
