# Get Schema from Working Cluster!

## Perfect Solution: Copy Schema from Your Working IQGeo Instance

You already have a **working IQGeo cluster**! We can export the database schema from it and import it to the new cluster.

---

## On Your Server - 2 Simple Steps:

### Step 1: Export Schema from Working Cluster

```bash
cd /opt/iqgeo-application-deployment
git pull

# Export schema from working database
./export-working-db-schema.sh
```

You'll be prompted for:
- Working cluster database host (e.g., `10.42.42.5` or whatever your working DB is)
- Database name (default: `iqgeo`)
- Database user (default: `iqgeo`)
- Database password

This creates: `working-db-schema.sql` (schema only, no data)

### Step 2: Import Schema to New Database

```bash
# Import the schema to new database
./import-schema.sh
```

This will:
1. ✅ Copy schema file to new database server (10.42.42.9)
2. ✅ Import all tables, views, sequences, indexes
3. ✅ Verify import (count tables)
4. ✅ Restart the application pod
5. ✅ Monitor startup and show status

---

## What Gets Exported:

From your working cluster:
- ✅ All table definitions (`CREATE TABLE`)
- ✅ All views (`CREATE VIEW`)
- ✅ All sequences (`CREATE SEQUENCE`)
- ✅ All indexes (`CREATE INDEX`)
- ✅ All constraints (primary keys, foreign keys)
- ❌ No data (just the structure)

---

## Expected Result:

After importing the schema:
- ✅ Database will have all required tables (`datasource`, `setting`, etc.)
- ✅ Application pod will start successfully
- ✅ Pod will become `Running (1/1 Ready)`
- ✅ Service will get LoadBalancer IP
- ✅ Application will be accessible! 🎉

---

## New Database Credentials:

```
Host: 10.42.42.9
Port: 5432
Database: iqgeo
Username: iqgeo
Password: IQGeoXHKtCMFtrPRrjV012026!
```

*(Saved in `database-setup-output.txt`)*

---

## If You Need to Check Working Cluster First:

Connect to working database:
```bash
# On working cluster
PGPASSWORD='your_working_password' psql -h working_db_host -U iqgeo -d iqgeo

# List tables
\dt

# Count tables
SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';
```

---

## After Import - Validate:

```bash
# Wait for pod to be ready
./wait-for-ready.sh

# Or check manually
kubectl get pods -n iqgeo
kubectl get svc -n iqgeo

# Push results
git add schema-import-output.txt
git commit -m "Schema imported from working cluster"
git push
```

---

## Troubleshooting:

**If you don't have pg_dump on your local machine:**
```bash
# Install PostgreSQL client tools
# Ubuntu/Debian:
sudo apt-get install postgresql-client

# macOS:
brew install postgresql

# Or run export directly from database server
ssh root@working_db_host
pg_dump -U iqgeo -d iqgeo --schema-only --no-owner --no-privileges > /tmp/schema.sql
# Then copy to your machine: scp root@working_db_host:/tmp/schema.sql .
```

**If export fails:**
You can also dump from within a working pod:
```bash
kubectl exec -n <namespace> <working-iqgeo-pod> -- pg_dump -h db_host -U iqgeo -d iqgeo --schema-only
```
