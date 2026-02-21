# Fix Missing PVC Issue

## Problem
After `terraform apply -replace`, the PVC was deleted but not recreated. Pod is stuck:

```
persistentvolumeclaim "iqgeo-platform-shared-data" not found
```

## Quick Manual Fix

### On Your Server:

```bash
cd /opt/iqgeo-application-deployment

# 1. Check if PVC is stuck in terminating
kubectl get pvc -n iqgeo -o wide

# 2. Force delete if stuck
kubectl delete pvc iqgeo-platform-shared-data -n iqgeo --force --grace-period=0 2>/dev/null || echo "Already deleted"

# 3. Wait for complete cleanup
sleep 10

# 4. Reapply Terraform
terraform apply -auto-approve

# 5. Wait for PVC to be created
sleep 30

# 6. Check status
kubectl get pvc -n iqgeo
kubectl get pods -n iqgeo

# 7. If PVC is still not created, check storage provisioner
kubectl get pods -n local-path-storage
kubectl get storageclass

# 8. Validate
./deploy-and-validate.sh
git add deployment-status.txt
git commit -m "Post PVC fix validation"
git push
```

---

## If Storage Provisioner is Not Running:

```bash
# Check local-path-provisioner
kubectl get pods -n local-path-storage

# If not running, may need to reinstall from prerequisites
cd /opt/iqgeo-onprem-deployment/terraform
terraform apply
```

---

## Alternative: Use Automated Script

```bash
cd /opt/iqgeo-application-deployment
git pull

# Run automated fix
./fix-missing-pvc.sh

# Push results
git add pvc-fix-output.txt
git commit -m "PVC fix results"
git push
```

---

## Expected Result:

After fix:
```
NAME                         STATUS   VOLUME        CAPACITY   ACCESS MODES   STORAGECLASS
iqgeo-platform-shared-data   Bound    pvc-xxxxx     50Gi       RWO            efs
```

Pod should move from `Pending` to `Init:0/1` to `Running`.
