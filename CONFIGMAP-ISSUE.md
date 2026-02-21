# ConfigMap Database Values Issue

## Problem Summary

The IQGeo Helm chart is **not mapping** database configuration from Helm values to the ConfigMap environment variables.

### What We've Tried:

1. ✅ Added `platform.database.*` in `main.tf` values block
2. ✅ Added root-level `database.*` in `main.tf` values block
3. ✅ Added both `database.*` and `platform.database.*` in `set_values` to force override
4. ❌ **ConfigMap is still generated with empty/wrong values**

### Result:

Even though Helm shows our database config:
```yaml
platform:
  database:
    host: 10.42.42.9
    port: 5432
    user: iqgeo
    password: 6hPfVGmi9gMMhhmE5pR64xDz4ahcQnvg
```

The generated ConfigMap has:
```yaml
MYW_DB_HOST: ""          ← EMPTY!
PGHOST: ""               ← EMPTY!
MYW_DB_USERNAME: postgres  ← Wrong
MYW_DB_PASSWORD: iqgeo     ← Wrong
```

---

## Root Cause

The Helm chart template for the ConfigMap is **not reading** from `.Values.database.*` or `.Values.platform.database.*`.

It likely:
- Has hardcoded defaults in the template
- Expects a different values structure
- Has a bug in the template logic

---

## Solution: Manual ConfigMap Patch

Since the Helm chart won't generate the ConfigMap correctly, we patch it directly after deployment:

```bash
kubectl patch configmap iqgeo-platform-configmap -n iqgeo --type merge -p '{
  "data": {
    "MYW_DB_HOST": "10.42.42.9",
    "PGHOST": "10.42.42.9",
    "MYW_DB_USERNAME": "iqgeo",
    # ... etc
  }
}'
```

Then delete the pod to pick up the new values:
```bash
kubectl delete pod -n iqgeo -l app=iqgeo-platform
```

---

## Automated Fix

Use the provided script:
```bash
./patch-configmap.sh
```

This will:
1. Patch the ConfigMap
2. Restart the pod
3. Verify the database connection works

---

## Long-Term Fix

To make this permanent (survive Helm upgrades), we should either:

1. **Fix the Helm chart templates** (if we have access to the chart source)
2. **Use a post-install Helm hook** to patch the ConfigMap
3. **Add to Terraform** as a `kubernetes_config_map` resource that depends on the Helm release

For now, the manual patch works and can be re-applied if needed.
