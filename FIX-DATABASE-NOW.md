# Fix Database Connection Issue

## Problem Found ✅
Init container is stuck trying to connect to database but **hostname is missing**:
```
:5432 - no response
ERROR: :5432 not accepting connections
```

The database host (`10.42.42.9`) is not being passed to the init container.

## Root Cause
Similar to other configuration issues, the Helm chart is not picking up the database configuration from the `values` block. We need to force it using `--set` (via `set_values`).

---

## Solution Applied

Added database configuration to `set_values` in `terraform.tfvars`:

```hcl
{
  name  = "platform.database.host"
  value = "10.42.42.9"
},
{
  name  = "platform.database.port"
  value = "5432"
},
# ... and other DB settings
```

---

## On Your Server - Apply the Fix:

```bash
cd /opt/iqgeo-application-deployment
git pull

# Run the fix script
./fix-database-connection.sh > db-fix-output.txt 2>&1

# View results
cat db-fix-output.txt

# Push results back
git add db-fix-output.txt
git commit -m "Database connection fix results"
git push
```

---

## What the Script Does:

1. ✅ Deletes the current failing pod
2. ✅ Applies Terraform with forced database configuration
3. ✅ Waits for new pod to start
4. ✅ Checks init container logs to verify DB connection

---

## Expected Result:

Init container logs should show:
```
Connecting to 10.42.42.9:5432...
✅ Database connection successful
```

Then the main container will start and the pod will become `Running`.

---

## After Fix - Validate:

```bash
./deploy-and-validate.sh
git add deployment-status.txt
git commit -m "Post DB fix validation"
git push
```

Expected status:
- ✅ PVC: Bound
- ✅ Pod: Running (1/1)
- ✅ Service: LoadBalancer with external IP
