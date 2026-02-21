# Database Password Configuration

## Current Password: `MrsIQGEO`

This is the password used in your working cluster and is now configured across all Terraform and initialization scripts.

---

## Quick Fix Instructions

### Option 1: Reset Database Password to Match (RECOMMENDED)

Run this on your server where PostgreSQL is accessible:

```bash
# Connect to PostgreSQL as superuser (usually postgres)
psql -U postgres -h 10.42.42.9 -p 5432

# Then run:
ALTER USER iqgeo WITH PASSWORD 'MrsIQGEO';
GRANT ALL PRIVILEGES ON DATABASE iqgeo TO iqgeo;
\q
```

### Option 2: Use the Reset Script

If you prefer an automated approach:

```bash
cd /opt/iqgeo-application-deployment
git pull
./reset-database-password.sh
```

Note: This will prompt you for the postgres superuser password.

---

## After Password Reset

Once the database password is set to `MrsIQGEO`, run:

```bash
cd /opt/iqgeo-application-deployment
git pull

# 1. Apply Terraform with correct password
terraform apply -auto-approve

# 2. Initialize database schema
./initialize-database-schema.sh > initialize-output.txt 2>&1

# 3. Verify tables were created
./verify-database-tables.sh

# 4. Restart application pods
./restart-iqgeo-pods.sh

# 5. Check pod status
kubectl get pods -n iqgeo
kubectl logs -n iqgeo -l app=iqgeo-platform --tail=50
```

---

## Password Storage Locations

All updated to use `MrsIQGEO`:
- `terraform.tfvars` (line 31)
- `terraform.tfvars` set_values (lines 123, 144)
- `initialize-database-schema.sh` (line 14)
- `verify-database-tables.sh` (line 14)
- `reset-database-password.sh` (line 17)

**REMEMBER THIS PASSWORD:** `MrsIQGEO`
