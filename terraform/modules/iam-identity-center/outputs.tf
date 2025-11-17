output "sso_roles_found" {
  description = "SSO roles found and added to EKS"
  value       = keys(aws_eks_access_entry.sso_roles)
}

output "setup_complete" {
  description = "Setup status"
  value       = <<-EOT
  ✅ EKS Access Entries created for SSO roles
  
  Found roles: ${join(", ", keys(local.sso_role_map))}
  Added to EKS: ${join(", ", keys(aws_eks_access_entry.sso_roles))}
  
  To login:
  1. aws configure sso
  2. aws sso login --profile <profile-name>
  3. aws eks update-kubeconfig --name ${var.cluster_name} --profile <profile-name>
  EOT
}
