# Setup Database and Deploy Application

## Automated Database Setup & Configuration

This script will create a fresh PostgreSQL database with proper credentials and configure the application automatically.

---

## On Your Server - Run This:

```bash
cd /opt/iqgeo-application-deployment
git pull

# Run the automated setup (requires SSH access to database server)
./setup-database-and-patch.sh

# Push results
git add database-setup-output.txt
git commit -m "Database setup completed"
git push
```

---

## What This Script Does:

1. ✅ Generates a secure random password
2. ✅ Connects to PostgreSQL server (10.42.42.9) via SSH
3. ✅ Creates database user `iqgeo` with the new password
4. ✅ Creates database `iqgeo` owned by `iqgeo` user
5. ✅ Grants all necessary privileges
6. ✅ Tests the database connection
7. ✅ Updates ConfigMap with correct credentials
8. ✅ Restarts the pod
9. ✅ Monitors startup and shows status
10. ✅ Displays the new credentials (save them!)

---

## Requirements:

- ✅ SSH access configured: `root@10.42.42.9` (using SSH keys)
- ✅ Sudo privileges on database server
- ✅ PostgreSQL installed on 10.42.42.9

**Note:** The script uses `scp` and `ssh` with your authorized keys to connect as `root@10.42.42.9`.

---

## After Script Completes:

The script will display the new database credentials. **Save them securely!**

Then optionally update your terraform.tfvars files for future deployments:
1. `/opt/iqgeo-onprem-deployment/terraform/terraform.tfvars` (line 24)
2. `/opt/iqgeo-application-deployment/terraform.tfvars` (line 31)

---

## If Pod Needs More Time:

```bash
# Continue monitoring
./wait-for-ready.sh

# Push results
git add ready-status.txt
git commit -m "Pod ready status"
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
