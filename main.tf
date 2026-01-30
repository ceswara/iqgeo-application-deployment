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

# Deploy IQGeo Application via Helm Chart
resource "helm_release" "iqgeo" {
  name       = var.release_name
  repository = var.helm_repository
  chart      = var.helm_chart
  version    = var.helm_chart_version
  namespace  = var.namespace
  create_namespace = var.create_namespace

  wait    = true
  timeout = var.helm_timeout

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
      } : {
        enabled = false
      }

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
