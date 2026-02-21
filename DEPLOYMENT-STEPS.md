# IQGeo Application Deployment Steps

## Current Issues to Fix

1. **Harbor secret missing in `iqgeo` namespace** → Pods can't pull images (401 Unauthorized)
2. **PVC has wrong access mode** (ReadWriteMany instead of ReadWriteOnce)

---

## Step 1: Apply Prerequisites (Create Harbor Secret)

On your server:

```bash
cd /path/to/iqgeo-onprem-deployment/terraform
git pull

# Edit terraform.tfvars to set Harbor credentials:
nano terraform.tfvars  # or vi, vim, etc.
```

Make sure these values are set:
```hcl
harbor_username = "robot$techwave"
harbor_password = "6hPfVGmi9gMMhhmE5pR64xDz4ahcQnvg"
```

Then apply:
```bash
terraform apply
```

This creates the `harbor-repository` secret in both `default` and `iqgeo` namespaces.

---

## Step 2: Deploy Application

```bash
cd /path/to/iqgeo-application-deployment
git pull

# Clean up old resources
kubectl delete hpa iqgeo-platform-hpa -n iqgeo 2>/dev/null || true
kubectl delete hpa iqgeo-platform--worker-hpa -n iqgeo 2>/dev/null || true
kubectl scale deployment iqgeo-platform -n iqgeo --replicas=0
sleep 10
kubectl delete pvc iqgeo-platform-shared-data -n iqgeo 2>/dev/null || true

# Apply with correct values
terraform apply -replace=helm_release.iqgeo
```

---

## Step 3: Validate Deployment

```bash
./deploy-and-validate.sh
git add deployment-status.txt
git commit -m "Deployment status"
git push
```

---

## Expected Results

After successful deployment:
- ✅ PVC: **Bound** with **ReadWriteOnce**
- ✅ Deployment: **1/1** replicas ready
- ✅ Pod: **Running** (not Pending/ImagePullBackOff)
- ✅ Service: LoadBalancer with external IP

---

## Troubleshooting

If issues persist, run the validation script and share the output:
```bash
./deploy-and-validate.sh
cat deployment-status.txt
```
