output "namespace" {
  description = "ArgoCD namespace"
  value       = kubernetes_namespace.argocd.metadata[0].name
}

output "argocd_version" {
  description = "Deployed ArgoCD version"
  value       = helm_release.argocd.version
}
