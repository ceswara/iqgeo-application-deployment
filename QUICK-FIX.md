# Quick Fix: Copy Database Schema from Working Cluster

## The Problem
New database is empty (0 tables), application crashes trying to access non-existent tables.

## The Solution
Export schema from your **working IQGeo cluster** and import it to the new one!

---

## On Your Server - Run These 2 Commands:

```bash
cd /opt/iqgeo-application-deployment
git pull

# Step 1: Export schema from working cluster
./export-working-db-schema.sh

# Step 2: Import to new database
./import-schema.sh
```

Done! Application should start successfully. 🎉

---

## What These Scripts Do:

### export-working-db-schema.sh
1. Prompts for your working database credentials
2. Uses `pg_dump --schema-only` to export structure (no data)
3. Creates `working-db-schema.sql` file
4. Shows statistics (number of tables, views, etc.)

### import-schema.sh
1. Copies schema file to new database server (10.42.42.9)
2. Imports schema using `psql`
3. Verifies tables were created
4. Restarts application pod
5. Monitors startup and shows status

---

## Expected Timeline:

- **Export**: 30 seconds - 2 minutes (depending on schema size)
- **Import**: 1-3 minutes (depending on schema complexity)
- **Pod restart**: 1-2 minutes (image pull, init, startup)

**Total**: ~5 minutes to fully working application!

---

## New Database Info:

```
Host: 10.42.42.9
Database: iqgeo
Username: iqgeo
Password: IQGeoXHKtCMFtrPRrjV012026!
```

---

## After Import - Verify:

```bash
# Check pod status
kubectl get pods -n iqgeo

# Check service
kubectl get svc iqgeo-platform -n iqgeo

# Check logs
kubectl logs -n iqgeo -l app=iqgeo-platform --tail=50

# Wait for ready status
./wait-for-ready.sh
```

---

## If You Get Errors:

**"pg_dump: command not found"**
```bash
# Install PostgreSQL client
sudo apt-get install postgresql-client  # Ubuntu/Debian
brew install postgresql                  # macOS
```

**"Connection refused to working database"**
- Check working database host/IP is correct
- Verify database is accessible from your machine
- Check firewall rules

**"Import failed"**
- Check new database credentials are correct
- Verify SSH access to 10.42.42.9
- Check logs in `schema-import-output.txt`

---

## Benefits of This Approach:

✅ **Fast** - Just copies structure, not data  
✅ **Exact** - Gets the schema your working cluster uses  
✅ **Safe** - No changes to working cluster  
✅ **Automated** - Scripts handle everything  
✅ **Verified** - Checks and validates each step  

No need to contact IQGeo support or search for documentation! 🚀
