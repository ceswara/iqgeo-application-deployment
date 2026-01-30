# IQGeo Application Deployment - Terraform

**Application Deployment Repository** - Deploys IQGeo application pods, services, and deployments on Kubernetes.

> **Note**: This repository is for **application deployment only**. 
> - For Kubernetes cluster setup, use [k8s-cluster-setup](https://github.com/ceswara/k8s-cluster-setup)
> - For prerequisites (secrets, storage), use [iqgeo-onprem-deployment](https://github.com/ceswara/iqgeo-onprem-deployment)

## What This Repository Does

Deploys the **actual IQGeo application** using Helm charts:
- ✅ Deploys IQGeo Helm chart
- ✅ Creates IQGeo pods, services, deployments
- ✅ Configures application settings
- ✅ Manages application lifecycle

## Prerequisites

1. **Kubernetes cluster** already set up (from `k8s-cluster-setup`)
2. **Prerequisites** already configured (from `iqgeo-onprem-deployment`)
   - Harbor secret (`harbor-repository`)
   - Database secret (`pg-credential`)
   - Storage class (`iqgeo-storage`)
   - cert-manager (if using TLS)
3. **Terraform** installed (>= 1.0)
4. **kubectl** configured to access your Kubernetes cluster
5. **Helm** installed
6. **IQGeo Helm chart** available in repository

## Quick Start

1. **Copy the example variables file:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Edit `terraform.tfvars` with your values:**
   ```hcl
   # Helm Chart
   helm_repository = "https://harbor.delivery.iqgeo.cloud/chartrepo/iqgeo"
   helm_chart      = "iqgeo-platform"
   helm_chart_version = "2.14.0"
   
   # Image
   image_repository = "harbor.delivery.iqgeo.cloud/iqgeo/platform"
   image_tag        = "7.0.0"
   image_pull_secrets = "harbor-repository"
   
   # Database (must match prerequisites)
   db_host     = "10.42.42.9"
   db_password = "your_db_password"
   
   # Storage (must match prerequisites)
   storage_class = "iqgeo-storage"
   
   # Ingress
   ingress_enabled = true
   ingress_host    = "iqgeo.local"
   ingress_tls_secret = "iqgeo-tls-secret"
   ```

3. **Initialize Terraform:**
   ```bash
   terraform init
   ```

4. **Plan the deployment:**
   ```bash
   terraform plan
   ```

5. **Apply the configuration:**
   ```bash
   terraform apply
   ```

## Complete Deployment Workflow

### Step 1: Setup Infrastructure
```bash
cd k8s-cluster-setup
terraform apply
# ✅ Kubernetes cluster ready
```

### Step 2: Setup Prerequisites
```bash
cd iqgeo-onprem-deployment/terraform
terraform apply
# ✅ Secrets, storage, cert-manager ready
```

### Step 3: Deploy Application (This Repo)
```bash
cd iqgeo-application-deployment
terraform apply
# ✅ IQGeo application running
```

## Configuration Variables

See `terraform.tfvars.example` for all available variables.

### Key Variables:

- `helm_repository`: Helm chart repository URL
- `helm_chart`: Chart name (e.g., `iqgeo-platform`)
- `image_repository`: Container image repository
- `image_tag`: Container image tag/version
- `image_pull_secrets`: Secret name for pulling images (must match prerequisites)
- `db_host`, `db_password`: Database connection (must match prerequisites)
- `storage_class`: Storage class name (must match prerequisites)
- `ingress_host`: Domain name for application access
- `ingress_tls_secret`: TLS certificate secret (must match prerequisites)

## Verification

After deployment, verify IQGeo is running:

```bash
# Check pods
kubectl get pods -n default | grep iqgeo

# Check services
kubectl get svc -n default | grep iqgeo

# Check ingress
kubectl get ingress -n default

# Check application logs
kubectl logs -n default -l app=iqgeo
```

## Troubleshooting

1. **Pods not starting:**
   ```bash
   kubectl describe pod <pod-name> -n default
   kubectl logs <pod-name> -n default
   ```

2. **Image pull errors:**
   - Verify Harbor secret exists: `kubectl get secret harbor-repository -n default`
   - Check image pull secrets in pod spec

3. **Database connection errors:**
   - Verify database secret: `kubectl get secret pg-credential -n default`
   - Check database server is accessible from cluster

4. **Storage issues:**
   - Verify storage class: `kubectl get storageclass iqgeo-storage`
   - Check PVCs: `kubectl get pvc -n default`

## Repository Structure

This is **Repository 3** of 3:
1. **k8s-cluster-setup** - Infrastructure (Kubernetes cluster)
2. **iqgeo-onprem-deployment** - Prerequisites (secrets, storage)
3. **iqgeo-application-deployment** - Application (this repo)

See [REPO-STRUCTURE.md](../iqgeo-onprem-deployment/terraform/REPO-STRUCTURE.md) for complete workflow.

## Support

For issues:
1. Check prerequisites are set up correctly
2. Verify all secrets and storage classes exist
3. Check pod logs and events
4. Compare with working cluster using comparison scripts
