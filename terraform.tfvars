# Kubernetes Configuration
kubeconfig_path    = "~/.kube/config"
kubeconfig_context = ""

# Namespace
namespace        = "iqgeo"
create_namespace = false  # Namespace already created by prerequisites

# Helm Chart Configuration
release_name          = "iqgeo"
helm_repository       = ""  # Leave empty to use OCI registry
helm_chart_oci_registry = "harbor.delivery.iqgeo.cloud/helm"  # OCI registry path
helm_chart            = "iqgeo-platform"
helm_chart_version    = "2.14.0"  # Update with your actual chart version
helm_timeout          = 1800  # 30 minutes - give more time for NFS provisioning

# Harbor Authentication (for pulling Helm chart from OCI registry)
harbor_username = "robot$techwave"
harbor_password = "6hPfVGmi9gMMhhmE5pR64xDz4ahcQnvg"

# Image Configuration
image_repository   = "harbor.delivery.iqgeo.cloud/nmti-trials/editions-nmt-comms-cloud"
image_tag          = "7.3"
image_pull_policy  = "IfNotPresent"
image_pull_secrets = "harbor-repository"  # Must match secret from prerequisites

# Database Configuration (must match prerequisites)
db_host     = "10.42.42.9"
db_port     = "5432"
db_user     = "iqgeo"
db_password = "6hPfVGmi9gMMhhmE5pR64xDz4ahcQnvg"
db_name     = "iqgeo"

# Storage Configuration (must match prerequisites)
# Use "efs" StorageClass which uses local-path provisioner (local storage, not NFS)
storage_class = "efs"
storage_size  = "50Gi"

# Service Configuration
service_type = "LoadBalancer"
service_port = 80

# Ingress Configuration (matches working cluster)
ingress_enabled    = false  # Temporarily disabled to avoid chart backend.subName nil pointer
ingress_class      = "nginx"
ingress_host       = "iqgeo-tf.techwave.com"  # Terraform-deployed cluster
ingress_paths      = ["/"]
ingress_tls_enabled = true  # TLS is enabled in working cluster
ingress_tls_secret  = "iqgeo.tls-secret"  # Matches working cluster (note: uses dot, not dash)

# Resource Configuration (reduced for on-prem cluster with limited memory)
resources = {
  limits = {
    cpu    = "1"
    memory = "1Gi"
  }
  requests = {
    cpu    = "500m"
    memory = "512Mi"  # Reduced from 2Gi to fit on-prem nodes
  }
}

# Replica Configuration
replica_count = 1  # Reduced to 1 to fit on-prem cluster resources

# Force override using Helm --set (in case chart ignores values)
# Also disable HPA or set minReplicas to 1 (HPA was forcing 3 replicas)
set_values = [
  {
    name  = "replicaCount"
    value = "1"
  },
  {
    name  = "resources.requests.memory"
    value = "512Mi"
  },
  {
    name  = "resources.requests.cpu"
    value = "500m"
  },
  {
    name  = "resources.limits.memory"
    value = "1Gi"
  },
  {
    name  = "resources.limits.cpu"
    value = "1"
  },
  # Disable HPA or set minReplicas to 1 (HPA was overriding replicaCount)
  {
    name  = "autoscaling.enabled"
    value = "false"
  },
  # Alternative: if autoscaling.enabled doesn't work, try these:
  # {
  #   name  = "autoscaling.minReplicas"
  #   value = "1"
  # },
  # {
  #   name  = "hpa.enabled"
  #   value = "false"
  # }
]
