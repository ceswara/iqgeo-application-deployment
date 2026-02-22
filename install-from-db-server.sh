#!/bin/bash
# Run myw_db installation directly on database server (eliminates network timeout)

set -e

echo "=========================================="
echo "Install IQGeo Schema from DB Server"
echo "=========================================="
echo ""

DB_HOST="10.42.42.9"
DB_NAME="iqgeo"
DB_USER="iqgeo"
DB_PASSWORD="IQGeoXHKtCMFtrPRrjV012026!"
IMAGE="harbor.delivery.iqgeo.cloud/nmti-trials/editions-nmt-comms-cloud:7.3"
HARBOR_USER="robot\$techwave"
HARBOR_PASS="6hPfVGmi9gMMhhmE5pR64xDz4ahcQnvg"

echo "This will:"
echo "1. Install Docker on database server (if needed)"
echo "2. Pull IQGeo image directly to DB server"
echo "3. Run myw_db install on localhost (no network timeout)"
echo ""

ssh -o StrictHostKeyChecking=no root@$DB_HOST << ENDSSH
set -e

echo "Step 1: Checking Docker installation..."
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    systemctl start docker
    systemctl enable docker
    echo "✓ Docker installed"
else
    echo "✓ Docker already installed"
fi
echo ""

echo "Step 2: Recreating database..."
sudo -u postgres psql -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='iqgeo';" > /dev/null 2>&1
sudo -u postgres psql -c "DROP DATABASE IF EXISTS iqgeo;" | grep DROP
sudo -u postgres psql -c "CREATE DATABASE iqgeo OWNER iqgeo;" | grep CREATE
sudo -u postgres psql -d iqgeo -c "CREATE EXTENSION postgis;" | grep CREATE
sudo -u postgres psql -d iqgeo -c "CREATE EXTENSION postgis_topology;" | grep CREATE
echo "✓ Fresh database created"
echo ""

echo "Step 3: Logging into Harbor registry..."
echo "$HARBOR_PASS" | docker login harbor.delivery.iqgeo.cloud -u "$HARBOR_USER" --password-stdin
echo ""

echo "Step 4: Pulling IQGeo image..."
docker pull $IMAGE
echo ""

echo "Step 5: Running CORE installation (locally on DB server)..."
docker run --rm \
  -e PGHOST=localhost \
  -e PGDATABASE=$DB_NAME \
  -e PGUSER=$DB_USER \
  -e PGPASSWORD="$DB_PASSWORD" \
  -e MYW_DB_HOST=localhost \
  -e MYW_DB_NAME=$DB_NAME \
  -e MYW_DB_USERNAME=$DB_USER \
  -e MYW_DB_PASSWORD="$DB_PASSWORD" \
  --network=host \
  $IMAGE \
  /opt/iqgeo/platform/Tools/myw_db $DB_NAME install core

echo ""
echo "Step 6: Checking tables..."
sleep 3
TABLE_COUNT=\$(PGPASSWORD="$DB_PASSWORD" psql -h localhost -U $DB_USER -d $DB_NAME -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" | xargs)
echo "Tables: \$TABLE_COUNT"
echo ""

if [ "\$TABLE_COUNT" -gt 30 ]; then
    echo "✓✓✓ CORE INSTALLED - \$TABLE_COUNT tables ✓✓✓"
    echo ""
    echo "Step 7: Installing COMMS..."
    docker run --rm \
      -e PGHOST=localhost \
      -e PGDATABASE=$DB_NAME \
      -e PGUSER=$DB_USER \
      -e PGPASSWORD="$DB_PASSWORD" \
      -e MYW_DB_HOST=localhost \
      -e MYW_DB_NAME=$DB_NAME \
      -e MYW_DB_USERNAME=$DB_USER \
      -e MYW_DB_PASSWORD="$DB_PASSWORD" \
      --network=host \
      $IMAGE \
      /opt/iqgeo/platform/Tools/myw_db $DB_NAME install comms
    
    TABLE_COUNT=\$(PGPASSWORD="$DB_PASSWORD" psql -h localhost -U $DB_USER -d $DB_NAME -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" | xargs)
    echo ""
    echo "Final tables: \$TABLE_COUNT"
else
    echo "✗ CORE FAILED - only \$TABLE_COUNT tables"
fi

echo ""
echo "Step 8: Verifying critical tables..."
for TABLE in setting datasource myw_user; do
    EXISTS=\$(PGPASSWORD="$DB_PASSWORD" psql -h localhost -U $DB_USER -d $DB_NAME -t -c "SELECT EXISTS (SELECT FROM pg_tables WHERE schemaname='public' AND tablename='\$TABLE');" | xargs)
    if [ "\$EXISTS" = "t" ]; then
        echo "   ✓ \$TABLE"
    else
        echo "   ✗ \$TABLE missing"
    fi
done

ENDSSH

echo ""
echo "=========================================="
echo "Installation Complete"
echo "=========================================="
echo ""
echo "Next: ./restart-iqgeo-pods.sh"
