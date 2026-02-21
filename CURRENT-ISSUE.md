# Current Issue: ImagePullSecret Name Mismatch

## Problem Found
✅ **PVC**: Fixed - Now Bound with ReadWriteOnce  
❌ **Pod**: Still failing with `Init:ImagePullBackOff` - 401 Unauthorized

## Root Cause
The deployment is configured to use imagePullSecret named `harbor-registry-cred`, but the actual secret created by prerequisites is named `harbor-repository`.

**Evidence:**
```bash
# What the deployment expects:
kubectl get deployment iqgeo-platform -n iqgeo -o jsonpath='{.spec.template.spec.imagePullSecrets}'
# Shows: [{"name": "harbor-registry-cred"}]

# What we actually have:
kubectl get secret -n iqgeo | grep harbor
# Shows: harbor-repository
```

## Fix Applied
Added Helm override to force the correct imagePullSecret name:

```hcl
{
  name  = "imagePullSecrets[0].name"
  value = "harbor-repository"
}
```

## Next Steps on Server

1. **Pull the fix:**
```bash
cd /path/to/iqgeo-application-deployment
git pull
```

2. **Apply the fix:**
```bash
./fix-imagepullsecret.sh
```

OR manually:
```bash
terraform apply -replace=helm_release.iqgeo
```

3. **Validate:**
```bash
./deploy-and-validate.sh
git add deployment-status.txt
git commit -m "Post-fix validation"
git push
```

## Expected Outcome
After applying the fix:
- ✅ PVC: Bound (already fixed)
- ✅ Pod: Running (will be fixed by imagePullSecret)
- ✅ Deployment: 1/1 replicas ready
- ✅ Service: External IP assigned
