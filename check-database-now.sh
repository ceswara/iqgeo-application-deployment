#!/bin/bash
# Quick check of current database state

echo "=========================================="
echo "Database Status Check"
echo "=========================================="
echo ""

DB_HOST="10.42.42.9"
DB_NAME="iqgeo"
DB_USER="iqgeo"
DB_PASSWORD="IQGeoXHKtCMFtrPRrjV012026!"

echo "Checking database: $DB_USER@$DB_HOST/$DB_NAME"
echo ""

ssh -o StrictHostKeyChecking=no root@$DB_HOST << ENDSSH
echo "1. Table count:"
PGPASSWORD="$DB_PASSWORD" psql -h localhost -U $DB_USER -d $DB_NAME -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';"
echo ""

echo "2. Critical tables check:"
for TABLE in setting datasource myw_user myw_feature_type layer application; do
    EXISTS=\$(PGPASSWORD="$DB_PASSWORD" psql -h localhost -U $DB_USER -d $DB_NAME -t -c "SELECT EXISTS (SELECT FROM pg_tables WHERE schemaname='public' AND tablename='$TABLE');" | xargs)
    if [ "\$EXISTS" = "t" ]; then
        echo "   ✓ $TABLE exists"
    else
        echo "   ✗ $TABLE missing"
    fi
done
echo ""

echo "3. First 30 tables:"
PGPASSWORD="$DB_PASSWORD" psql -h localhost -U $DB_USER -d $DB_NAME -c "\dt" | head -35
echo ""

echo "4. Users in database:"
PGPASSWORD="$DB_PASSWORD" psql -h localhost -U $DB_USER -d $DB_NAME -c "SELECT username FROM myw_user;" 2>&1
echo ""
ENDSSH

echo "=========================================="
echo "Check Complete"
echo "=========================================="
