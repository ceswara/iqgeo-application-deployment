#!/bin/bash
# Show what's currently in the database

echo "=========================================="
echo "Current Database Schema"
echo "=========================================="
echo ""

DB_HOST="10.42.42.9"
DB_NAME="iqgeo"
DB_USER="iqgeo"
DB_PASSWORD="IQGeoXHKtCMFtrPRrjV012026!"

ssh -o StrictHostKeyChecking=no root@$DB_HOST << ENDSSH
echo "Database: $DB_NAME on $DB_HOST"
echo ""

echo "1. Schemas in database:"
PGPASSWORD="$DB_PASSWORD" psql -h localhost -U $DB_USER -d $DB_NAME -c "\dn"
echo ""

echo "2. Tables in database:"
PGPASSWORD="$DB_PASSWORD" psql -h localhost -U $DB_USER -d $DB_NAME -c "\dt"
echo ""

echo "3. Table count per schema:"
PGPASSWORD="$DB_PASSWORD" psql -h localhost -U $DB_USER -d $DB_NAME -c "SELECT schemaname, COUNT(*) as table_count FROM pg_tables WHERE schemaname NOT IN ('pg_catalog', 'information_schema') GROUP BY schemaname;"
echo ""

echo "4. Extensions installed:"
PGPASSWORD="$DB_PASSWORD" psql -h localhost -U $DB_USER -d $DB_NAME -c "\dx"
echo ""

echo "5. Total user tables:"
PGPASSWORD="$DB_PASSWORD" psql -h localhost -U $DB_USER -d $DB_NAME -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';"
echo ""

echo "6. Database size:"
PGPASSWORD="$DB_PASSWORD" psql -h localhost -U $DB_USER -d $DB_NAME -c "SELECT pg_size_pretty(pg_database_size('$DB_NAME'));"
ENDSSH

echo ""
echo "=========================================="
