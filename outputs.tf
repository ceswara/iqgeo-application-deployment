output "release_name" {
  description = "Helm release name"
  value       = helm_release.iqgeo.name
}

output "namespace" {
  description = "Kubernetes namespace"
  value       = helm_release.iqgeo.namespace
}

output "status" {
  description = "Helm release status"
  value       = helm_release.iqgeo.status
}

output "version" {
  description = "Helm chart version"
  value       = helm_release.iqgeo.version
}

output "application_url" {
  description = "IQGeo application URL"
  value       = var.ingress_enabled && var.ingress_host != "" ? "https://${var.ingress_host}" : "Check service: kubectl get svc -n ${var.namespace}"
}
