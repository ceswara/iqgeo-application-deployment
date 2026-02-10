terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
  required_version = ">= 1.0"
}

# Kubernetes Provider
provider "kubernetes" {
  config_path    = var.kubeconfig_path != "" ? var.kubeconfig_path : null
  config_context = var.kubeconfig_context != "" ? var.kubeconfig_context : null
}

provider "helm" {
  kubernetes {
    config_path    = var.kubeconfig_path != "" ? var.kubeconfig_path : null
    config_context = var.kubeconfig_context != "" ? var.kubeconfig_context : null
  }
}

# Authenticate with Harbor OCI registry before pulling chart
# The Terraform Helm provider requires helm CLI to be installed and authenticated
resource "null_resource" "helm_registry_login" {
  count = var.helm_repository == "" && var.harbor_username != "" && var.harbor_password != "" ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      # Set PATH to include common binary locations
      export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"
      
      # Check if helm is installed (try common locations)
      HELM_CMD=""
      if command -v helm &> /dev/null; then
        HELM_CMD="helm"
      elif [ -f /usr/local/bin/helm ]; then
        HELM_CMD="/usr/local/bin/helm"
      elif [ -f /usr/bin/helm ]; then
        HELM_CMD="/usr/bin/helm"
      else
        echo "ERROR: helm CLI is required but not installed."
        echo "Please install helm: curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
        exit 1
      fi
      
      # Extract Harbor host from registry URL
      HARBOR_HOST=$(echo "${var.helm_chart_oci_registry}" | cut -d'/' -f1)
      
      # Login to Harbor registry
      # Use the same form that works manually:
      #   echo 'PASSWORD' | helm registry login harbor.delivery.iqgeo.cloud -u 'robot$techwave' --password-stdin
      # Username is hard-coded here because shell will misinterpret the $ in a variable assignment
      echo "${var.harbor_password}" | $HELM_CMD registry login $HARBOR_HOST -u 'robot$techwave' --password-stdin
    EOT
  }

  triggers = {
    harbor_username = var.harbor_username
    harbor_registry = var.helm_chart_oci_registry
  }
}

# Deploy IQGeo Application via Helm Chart
resource "helm_release" "iqgeo" {
  name       = var.release_name
  # Use OCI registry format for Harbor (e.g., oci://harbor.delivery.iqgeo.cloud/helm/iqgeo-platform)
  # If helm_repository is empty, assume chart is specified as OCI URL
  repository = var.helm_repository != "" ? var.helm_repository : null
  chart      = var.helm_repository != "" ? var.helm_chart : "oci://${var.helm_chart_oci_registry}/${var.helm_chart}"
  version    = var.helm_chart_version != "" ? var.helm_chart_version : null
  namespace  = var.namespace
  create_namespace = var.create_namespace

  wait    = true
  timeout = var.helm_timeout

  depends_on = [null_resource.helm_registry_login]

  # Values from variables
  values = [
    yamlencode({
      # Image configuration
      image = {
        repository = var.image_repository
        tag        = var.image_tag
        pullPolicy = var.image_pull_policy
      }

      # Image pull secrets
      imagePullSecrets = var.image_pull_secrets != "" ? [var.image_pull_secrets] : []

      # Database configuration
      database = {
        host     = var.db_host
        port     = var.db_port
        user     = var.db_user
        password = var.db_password
        name     = var.db_name
      }

      # Storage configuration
      persistence = {
        enabled      = true
        storageClass = var.storage_class
        size         = var.storage_size
      }

      # Service configuration
      service = {
        type = var.service_type
        port = var.service_port
      }

      # Ingress configuration
      ingress = var.ingress_enabled ? {
        enabled   = true
        className = var.ingress_class
        hosts = [
          {
            host  = var.ingress_host
            paths = var.ingress_paths
          }
        ]
        tls = var.ingress_tls_enabled ? [
          {
            secretName = var.ingress_tls_secret
            hosts      = [var.ingress_host]
          }
        ] : []
      } : null

      # Resource limits
      resources = var.resources

      # Replica count
      replicaCount = var.replica_count

      # Additional values (if provided)
      extra = var.extra_values
    })
  ]

  # Set individual values (alternative to values file)
  dynamic "set" {
    for_each = var.set_values
    content {
      name  = set.value.name
      value = set.value.value
    }
  }
}
