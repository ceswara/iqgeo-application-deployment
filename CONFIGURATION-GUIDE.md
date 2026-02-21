# Configuration Guide for terraform.tfvars

## Required Changes

You **MUST** update these values in `terraform.tfvars`:

### 1. Database Password (REQUIRED)
```hcl
db_password = "YOUR_DB_PASSWORD"  # ⬅️ Change this to your actual password
```

### 2. Image Repository (REQUIRED)
```hcl
image_repository = "harbor.delivery.iqgeo.cloud/nmti-trials/editions-nmt-comms-cloud"  # ⬅️ Set this
image_tag        = "7.3"  # ⬅️ Set this (matches your working cluster)
```

### 3. Helm Repository (REQUIRED if using Helm chart from repository)
```hcl
helm_repository    = "https://harbor.delivery.iqgeo.cloud/chartrepo/iqgeo"  # ⬅️ Set if you have Helm repo
helm_chart         = "iqgeo-platform"  # ✅ Already correct
helm_chart_version = "2.14.0"  # ⬅️ Set this (matches your working cluster)
```

**OR** if you have the Helm chart locally:
- Leave `helm_repository = ""` empty
- Use `helm_chart` pointing to local chart path

### 4. Ingress Host (REQUIRED if using ingress)
```hcl
ingress_host = "iqgeo-tf.techwave.com"  # ⬅️ Your domain
ingress_tls_secret = "iqgeo-tls-secret"  # ⬅️ Must match certificate from prerequisites
```

## Recommended Changes (to match your working cluster)

### Namespace
```hcl
namespace = "default"  # ✅ Already correct (IQGeo runs in default namespace)
```

### Storage (matches prerequisites)
```hcl
storage_class = "iqgeo-storage"  # ✅ Already correct
storage_size  = "50Gi"  # ✅ Already correct
```

### Image Pull Secrets (matches prerequisites)
```hcl
image_pull_secrets = "harbor-repository"  # ✅ Already correct
```

### Service Type (matches working cluster)
```hcl
service_type = "LoadBalancer"  # ✅ Already correct
```

## Complete Example terraform.tfvars

```hcl
# Kubernetes Configuration
kubeconfig_path    = "~/.kube/config"
kubeconfig_context = ""

# Namespace
namespace        = "default"
create_namespace = false

# Helm Chart Configuration
release_name       = "iqgeo"
helm_repository    = "https://harbor.delivery.iqgeo.cloud/chartrepo/iqgeo"  # Update if you have Helm repo
helm_chart         = "iqgeo-platform"
helm_chart_version = "2.14.0"  # Update with your chart version
helm_timeout       = 600

# Image Configuration
image_repository   = "harbor.delivery.iqgeo.cloud/nmti-trials/editions-nmt-comms-cloud"  # Update
image_tag          = "7.3"  # Update
image_pull_policy  = "IfNotPresent"
image_pull_secrets = "harbor-repository"  # ✅ Matches prerequisites

# Database Configuration
db_host     = "10.42.42.9"  # ✅ Already correct
db_port     = "5432"  # ✅ Already correct
db_user     = "iqgeo"  # ✅ Already correct
db_password = "YOUR_DB_PASSWORD"  # ⬅️ REQUIRED: Update this
db_name     = "iqgeo"  # ✅ Already correct

# Storage Configuration
storage_class = "iqgeo-storage"  # ✅ Matches prerequisites
storage_size  = "50Gi"  # ✅ Already correct

# Service Configuration
service_type = "LoadBalancer"  # ✅ Matches working cluster
service_port = 80  # ✅ Already correct

# Ingress Configuration
ingress_enabled    = true  # ✅ Enable if you want ingress
ingress_class      = "nginx"  # ✅ Already correct
ingress_host       = "iqgeo-tf.techwave.com"  # ⬅️ Update with your domain
ingress_paths      = ["/"]  # ✅ Already correct
ingress_tls_enabled = true  # ✅ Enable if you have certificate
ingress_tls_secret  = "iqgeo-tls-secret"  # ⬅️ Update if certificate name is different

# Resource Configuration
resources = {
  limits = {
    cpu    = "2"
    memory = "4Gi"
  }
  requests = {
    cpu    = "1"
    memory = "2Gi"
  }
}

# Replica Configuration
replica_count = 3  # ⬅️ Update to match working cluster (3 replicas)
```

## Quick Checklist

Before running `terraform apply`, make sure:

- [ ] `db_password` is set (REQUIRED)
- [ ] `image_repository` is set (REQUIRED)
- [ ] `image_tag` is set (REQUIRED)
- [ ] `helm_repository` or local chart path is configured (REQUIRED)
- [ ] `helm_chart_version` is set (if using Helm repo)
- [ ] `ingress_host` is set (if using ingress)
- [ ] `ingress_tls_secret` matches certificate from prerequisites
- [ ] `replica_count` matches your needs (working cluster has 3)

## Post-Deployment: Database Initialization

**IMPORTANT**: After first deployment, initialize the database schema:

```bash
./initialize-database-schema.sh
```

This is **required for fresh databases** and uses IQGeo's official `myw_db` tool to:
- Install Core Platform schema (v7.3)
- Install Network Manager Telecom schema (v7.3.3.5)
- Create all required tables, views, and functions

The pods will crash with `sqlalchemy.exc.NoSuchTableError` until this step is completed.

## Values That Match Prerequisites

These should match what you created in the prerequisites repo:

- ✅ `image_pull_secrets = "harbor-repository"` (secret in default namespace)
- ✅ `storage_class = "iqgeo-storage"` (created by prerequisites)
- ✅ `db_host = "10.42.42.9"` (your DB server)
- ✅ `ingress_tls_secret = "iqgeo-tls-secret"` (if certificate was created)
