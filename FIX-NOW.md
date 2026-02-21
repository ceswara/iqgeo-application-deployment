# Quick Fix for Harbor Credentials Issue

## Problem
Pods are failing with `ImagePullBackOff` due to incorrect Harbor credentials (401 Unauthorized).

## Solution
Run the automated fix script on your server.

---

## On Your Server - Run This:

```bash
cd /opt/iqgeo-application-deployment
git pull

# Run the fix script
./fix-harbor-credentials.sh > fix-output.txt 2>&1

# View the results
cat fix-output.txt

# Push results back
git add fix-output.txt
git commit -m "Harbor credentials fix results"
git push
```

---

## What the Script Does:

1. ✅ Checks current Harbor secret and credentials
2. ✅ Tests current credentials against Harbor registry
3. ✅ Deletes old incorrect secrets
4. ✅ Creates new secrets with correct credentials:
   - Username: `robot$techwave`
   - Password: `6hPfVGmi9gMMhhmE5pR64xDz4ahcQnvg`
5. ✅ Tests new credentials
6. ✅ Restarts IQGeo pods
7. ✅ Checks for image pull errors

---

## Expected Result:

After running the script:
- ✅ Harbor authentication: HTTP Status 200 or 307
- ✅ Pods: Running (not ImagePullBackOff)
- ✅ Deployment: 1/1 replicas ready

---

## If Issues Persist:

Run the full validation:
```bash
./deploy-and-validate.sh
git add deployment-status.txt
git commit -m "Post-fix validation"
git push
```
