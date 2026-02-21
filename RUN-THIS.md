# ❌ Database Empty - Application Cannot Auto-Initialize

## Current Status:

✅ Database user `iqgeo` created  
✅ Database `iqgeo` created  
✅ Password authentication working  
✅ Application connecting to database  
❌ Database has **0 tables** (empty)
❌ Application **CrashLoopBackOff** - cannot initialize schema

**Password:** `IQGeoXHKtCMFtrPRrjV012026!`

---

## The Problem:

The application tries to initialize the database schema but fails with a **chicken-and-egg issue**:

1. Application starts and tries to initialize database
2. During init, it uses SQLAlchemy `autoload=True` to reflect existing tables
3. Tables don't exist yet, so it crashes
4. Never gets to the point where it creates the tables
5. Pod restarts → loop continues

**Errors:**
- `sqlalchemy.exc.NoSuchTableError: datasource`
- `sqlalchemy.exc.NoSuchTableError: setting`

---

## On Your Server - Check Initialization Options:

```bash
cd /opt/iqgeo-application-deployment
git pull

# Check if there are special init flags or setup procedures
./check-init-options.sh

# Push results
git add init-options-check.txt
git commit -m "Init options check"
git push
```

---

## Likely Solutions:

### 1. Check for Skip/Disable Init Flag

There might be an environment variable like:
- `SKIP_DB_INIT=true`
- `AUTO_MIGRATE=false`  
- `DB_INIT_MODE=manual`

That tells the app to skip auto-initialization.

### 2. Pre-Populate Database Schema

IQGeo might require importing an initial schema before first start:

```bash
# If you have a schema.sql file
scp schema.sql root@10.42.42.9:/tmp/
ssh root@10.42.42.9
PGPASSWORD='IQGeoXHKtCMFtrPRrjV012026!' psql -h localhost -U iqgeo -d iqgeo -f /tmp/schema.sql
```

### 3. Run Manual Database Initialization

The application has `/opt/iqgeo/platform/Tools/myw_db.py` tool.

There might be a command like:
```bash
kubectl exec -it POD_NAME -n iqgeo -- /opt/iqgeo/platform/Tools/myw_db.py create-schema
# or
kubectl exec -it POD_NAME -n iqgeo -- /opt/iqgeo/platform/Tools/myw_db.py migrate
```

### 4. Contact IQGeo Support

This is a commercial product. They should have:
- Installation documentation
- Database initialization procedures
- Initial schema files or migration scripts

**Ask them:** "What is the correct procedure for first-time database setup for IQGeo Platform 7.3?"

---

## What This Script Checks:

1. ✅ PVC status
2. ✅ Pod status  
3. ✅ ConfigMap database values (MYW_DB_HOST, PGHOST, etc.)
4. ✅ Init container status and logs
5. ✅ Main container status and logs
6. ✅ Pod events
7. ✅ Service status
8. ✅ Summary with clear status indicators

---

## Expected Status After Fix:

- ✅ PVC: Bound
- ✅ ConfigMap: MYW_DB_HOST = "10.42.42.9" (not empty!)
- ✅ Init container: Successfully connected to database
- ✅ Pod: Running (1/1 Ready)
- ✅ Service: LoadBalancer with external IP
