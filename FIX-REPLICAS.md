# Fix Replica Count Issue

The deployment is stuck at 3 replicas even though `terraform.tfvars` has `replica_count = 1`.

## Solution: Run Script on Server

**On your server (where Terraform is installed):**

```bash
cd /path/to/iqgeo-application-deployment
git pull
./fix-replicas.sh
git add terraform-fix-output.txt
git commit -m "Fix replica count - terraform apply results"
git push
```

**Then on your local machine:**
```bash
cd /Users/sandeepdaddala/Desktop/iqgeo-application-deployment
git pull
cat terraform-fix-output.txt
```

The script will:
1. Check current state
2. Run `terraform apply -replace=helm_release.iqgeo`
3. Verify the fix worked
4. Export all output to `terraform-fix-output.txt`

## Manual Solution (if script doesn't work)

Run this command on the server:

```bash
cd /path/to/iqgeo-application-deployment
terraform apply -replace=helm_release.iqgeo
```

This will:
1. Destroy the existing Helm release
2. Recreate it with the correct values from `terraform.tfvars` (including `replica_count = 1`)

## Alternative: Manual Scale Down (Temporary Fix)

If you need immediate relief, run on your Kubernetes server:

```bash
# Scale down the deployment to 1 replica
kubectl scale deployment iqgeo-platform -n iqgeo --replicas=1

# Delete the extra pending pods
kubectl delete pod -n iqgeo -l app.kubernetes.io/name=iqgeo-platform --field-selector=status.phase=Pending

# Verify
kubectl get pods -n iqgeo
```

**Note:** If you scale down manually, Terraform might try to scale it back up on next apply. Use the `-replace` method above for a permanent fix.

## Why This Happened

Helm provider sometimes doesn't detect changes in values when the release was created with different values. The `-replace` flag forces Terraform to destroy and recreate the Helm release with the correct values from your `terraform.tfvars`.
