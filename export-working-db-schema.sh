#!/bin/bash
set -e

OUTPUT_FILE="working-db-schema.sql"

echo "========================================="
echo "Exporting Database Schema from Working Cluster"
echo "========================================="
echo ""

# You'll need to provide these from your working cluster
echo "Please provide information about your WORKING IQGeo cluster:"
echo ""
read -p "Working cluster database host (e.g., 10.42.42.X): " WORKING_DB_HOST
read -p "Working cluster database name (default: iqgeo): " WORKING_DB_NAME
WORKING_DB_NAME=${WORKING_DB_NAME:-iqgeo}
read -p "Working cluster database user (default: iqgeo): " WORKING_DB_USER
WORKING_DB_USER=${WORKING_DB_USER:-iqgeo}
read -sp "Working cluster database password: " WORKING_DB_PASSWORD
echo ""
echo ""

echo "Connecting to working database at $WORKING_DB_HOST..."
echo ""

# Export schema only (no data) from working database
PGPASSWORD="$WORKING_DB_PASSWORD" pg_dump \
  -h "$WORKING_DB_HOST" \
  -U "$WORKING_DB_USER" \
  -d "$WORKING_DB_NAME" \
  --schema-only \
  --no-owner \
  --no-privileges \
  -f "$OUTPUT_FILE"

echo "✅ Schema exported to $OUTPUT_FILE"
echo ""

# Show schema statistics
echo "Schema statistics:"
TABLE_COUNT=$(grep -c "CREATE TABLE" "$OUTPUT_FILE" || echo "0")
VIEW_COUNT=$(grep -c "CREATE VIEW" "$OUTPUT_FILE" || echo "0")
SEQUENCE_COUNT=$(grep -c "CREATE SEQUENCE" "$OUTPUT_FILE" || echo "0")
INDEX_COUNT=$(grep -c "CREATE INDEX" "$OUTPUT_FILE" || echo "0")

echo "  Tables: $TABLE_COUNT"
echo "  Views: $VIEW_COUNT"
echo "  Sequences: $SEQUENCE_COUNT"
echo "  Indexes: $INDEX_COUNT"
echo ""

# Show list of tables
echo "Tables in working database:"
grep "CREATE TABLE" "$OUTPUT_FILE" | awk '{print "  - " $3}' | sed 's/;$//' | head -20
if [ "$TABLE_COUNT" -gt 20 ]; then
    echo "  ... and $((TABLE_COUNT - 20)) more tables"
fi
echo ""

echo "========================================="
echo "Schema Export Complete!"
echo "========================================="
echo ""
echo "Now import this schema to your NEW database:"
echo ""
echo "  ssh root@10.42.42.9"
echo "  PGPASSWORD='IQGeoXHKtCMFtrPRrjV012026!' psql -h localhost -U iqgeo -d iqgeo -f /tmp/$OUTPUT_FILE"
echo ""
echo "Or run the import script:"
echo "  ./import-schema.sh"
echo ""
