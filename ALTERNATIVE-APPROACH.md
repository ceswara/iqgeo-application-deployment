# Alternative Approach: Import Schema from Working Cluster

The `myw_db install` tool keeps completing but not committing tables due to connection timeouts or transaction issues.

## Alternative Solution: Import Database Dump

If you have access to a **working IQGeo cluster**, export its database schema and import it:

### Step 1: Export from Working Cluster

On your working cluster's database server:

```bash
# Export only the schema (no data) from working database
pg_dump -h <WORKING_DB_HOST> -U iqgeo -d <WORKING_DB_NAME> \
  --schema-only --no-owner --no-privileges \
  -f /tmp/iqgeo-schema-only.sql

# OR export schema + essential seed data
pg_dump -h <WORKING_DB_HOST> -U iqgeo -d <WORKING_DB_NAME> \
  --no-owner --no-privileges \
  -f /tmp/iqgeo-complete.sql
```

### Step 2: Copy to New Environment

```bash
# Copy the dump file to your new cluster's server
scp /tmp/iqgeo-schema-only.sql root@<NEW_CLUSTER_SERVER>:/tmp/
```

### Step 3: Import to New Database

On your new database server (10.42.42.9):

```bash
# Create fresh database
sudo -u postgres psql -c "DROP DATABASE IF EXISTS iqgeo;"
sudo -u postgres psql -c "CREATE DATABASE iqgeo OWNER iqgeo;"
sudo -u postgres psql -d iqgeo -c "CREATE EXTENSION postgis;"
sudo -u postgres psql -d iqgeo -c "CREATE EXTENSION postgis_topology;"

# Import the schema
PGPASSWORD="IQGeoXHKtCMFtrPRrjV012026!" psql -h localhost -U iqgeo -d iqgeo -f /tmp/iqgeo-schema-only.sql
```

### Step 4: Restart IQGeo

```bash
cd /opt/iqgeo-application-deployment
./restart-iqgeo-pods.sh
kubectl get pods -n iqgeo
```

---

## Working Cluster Information

From your cluster dump (`cluster-dump-20260130-113153`), the working cluster was:
- **Host:** 172.21.34.14 (different from your new 10.42.42.9)
- **Database:** myappdbOct172025-10
- **User:** postgres
- **Password:** MrsIQGEO

Can you access this server to get a dump, or do you have another working IQGeo database?
