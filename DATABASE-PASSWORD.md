# Database Password Configuration

## Current Password: `IQGeoXHKtCMFtrPRrjV012026!`

This is the ACTUAL working password on your database server at 10.42.42.9 (tested and confirmed).
It is now configured across all Terraform and initialization scripts.

---

## Password Discovery

This password was discovered by testing multiple combinations:
- ❌ `MrsIQGEO` (from old working cluster dump - different database server)
- ❌ `iqgeo` (Helm chart default)
- ❌ `6hPfVGmi9gMMhhmE5pR64xDz4ahcQnvg` (Harbor token)
- ✅ `IQGeoXHKtCMFtrPRrjV012026!` (ACTUAL password on 10.42.42.9)

The database server at 10.42.42.9 already has this password configured for user `iqgeo`.

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

**REMEMBER THIS PASSWORD:** `IQGeoXHKtCMFtrPRrjV012026!`
