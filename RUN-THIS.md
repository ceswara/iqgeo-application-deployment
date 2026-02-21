# FIX REQUIRED: Database Password is Wrong!

## ❌ Issue: Password Authentication Failed

The application can connect to the database but the password is incorrect:
```
FATAL: password authentication failed for user "iqgeo"
```

## Root Cause:
We accidentally used the **Harbor password** instead of the **PostgreSQL password**.

---

## On Your Server - Do This:

### Step 1: Find the Correct Database Password

Check what password was set up on database server `10.42.42.9`:

**Option A: Check database server directly**
```bash
ssh 10.42.42.9
sudo -u postgres psql -c "\\du"  # List database users
```

**Option B: If user doesn't exist, create it**
```bash
ssh 10.42.42.9
sudo -u postgres psql
```
```sql
CREATE USER iqgeo WITH PASSWORD 'YOUR_CHOSEN_PASSWORD';
CREATE DATABASE iqgeo OWNER iqgeo;
GRANT ALL PRIVILEGES ON DATABASE iqgeo TO iqgeo;
\q
```

### Step 2: Update Password in ConfigMap

Replace `THE_ACTUAL_PASSWORD` with the real password:

```bash
cd /opt/iqgeo-application-deployment

kubectl patch configmap iqgeo-platform-configmap -n iqgeo --type merge -p '{
  "data": {
    "MYW_DB_PASSWORD": "THE_ACTUAL_PASSWORD",
    "PGPASSWORD": "THE_ACTUAL_PASSWORD"
  }
}'

# Restart pod
kubectl delete pod -n iqgeo -l app=iqgeo-platform

# Wait and check
sleep 60
kubectl get pods -n iqgeo
kubectl logs -n iqgeo -l app=iqgeo-platform --tail=30
```

### Step 3: Update terraform.tfvars Files (Optional - for future deployments)

**On server - Edit both files:**
1. `/opt/iqgeo-onprem-deployment/terraform/terraform.tfvars` - Line 24
2. `/opt/iqgeo-application-deployment/terraform.tfvars` - Line 31

Change: `db_password = "THE_ACTUAL_PASSWORD"`

---

## After Password Fix:

```bash
cd /opt/iqgeo-application-deployment

# Wait for pod to become ready
./wait-for-ready.sh

# Push results
git add ready-status.txt
git commit -m "Post password fix status"
git push
```

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
