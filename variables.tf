variable "kubeconfig_path" {
  description = "Path to kubeconfig file (leave empty for in-cluster config)"
  type        = string
  default     = "~/.kube/config"
}

variable "kubeconfig_context" {
  description = "Kubernetes context to use"
  type        = string
  default     = ""
}

variable "namespace" {
  description = "Kubernetes namespace for IQGeo application"
  type        = string
  default     = "default"
}

variable "create_namespace" {
  description = "Create namespace if it doesn't exist"
  type        = bool
  default     = false
}

variable "release_name" {
  description = "Helm release name"
  type        = string
  default     = "iqgeo"
}

variable "helm_repository" {
  description = "Helm chart repository URL"
  type        = string
  default     = ""
}

variable "helm_chart" {
  description = "Helm chart name"
  type        = string
  default     = "iqgeo-platform"
}

variable "helm_chart_version" {
  description = "Helm chart version"
  type        = string
  default     = ""
}

variable "helm_timeout" {
  description = "Helm install timeout in seconds"
  type        = number
  default     = 600
}

variable "image_repository" {
  description = "Container image repository"
  type        = string
  default     = ""
}

variable "image_tag" {
  description = "Container image tag"
  type        = string
  default     = "latest"
}

variable "image_pull_policy" {
  description = "Image pull policy"
  type        = string
  default     = "IfNotPresent"
}

variable "image_pull_secrets" {
  description = "Image pull secret name (e.g., harbor-repository)"
  type        = string
  default     = "harbor-repository"
}

variable "db_host" {
  description = "PostgreSQL database host"
  type        = string
  default     = ""
}

variable "db_port" {
  description = "PostgreSQL database port"
  type        = string
  default     = "5432"
}

variable "db_user" {
  description = "PostgreSQL database user"
  type        = string
  default     = "iqgeo"
}

variable "db_password" {
  description = "PostgreSQL database password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "iqgeo"
}

variable "storage_class" {
  description = "Storage class for persistent volumes"
  type        = string
  default     = "iqgeo-storage"
}

variable "storage_size" {
  description = "Storage size for IQGeo"
  type        = string
  default     = "50Gi"
}

variable "service_type" {
  description = "Kubernetes service type"
  type        = string
  default     = "LoadBalancer"
}

variable "service_port" {
  description = "Service port"
  type        = number
  default     = 80
}

variable "ingress_enabled" {
  description = "Enable ingress"
  type        = bool
  default     = false
}

variable "ingress_class" {
  description = "Ingress class name"
  type        = string
  default     = "nginx"
}

variable "ingress_host" {
  description = "Ingress hostname"
  type        = string
  default     = ""
}

variable "ingress_paths" {
  description = "Ingress paths"
  type        = list(string)
  default     = ["/"]
}

variable "ingress_tls_enabled" {
  description = "Enable TLS for ingress"
  type        = bool
  default     = false
}

variable "ingress_tls_secret" {
  description = "TLS secret name for ingress"
  type        = string
  default     = ""
}

variable "resources" {
  description = "Resource limits and requests"
  type = object({
    limits = object({
      cpu    = string
      memory = string
    })
    requests = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    limits = {
      cpu    = "2"
      memory = "4Gi"
    }
    requests = {
      cpu    = "1"
      memory = "2Gi"
    }
  }
}

variable "replica_count" {
  description = "Number of replicas"
  type        = number
  default     = 1
}

variable "set_values" {
  description = "Additional Helm values to set"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "extra_values" {
  description = "Extra Helm values (merged with main values)"
  type        = map(any)
  default     = {}
}
