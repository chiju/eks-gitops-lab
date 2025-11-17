output "instance_arn" {
  description = "IAM Identity Center instance ARN"
  value       = local.instance_arn
}

output "identity_store_id" {
  description = "Identity Store ID"
  value       = local.identity_store_id
}

output "sso_roles_found" {
  description = "SSO roles found and mapped"
  value       = local.sso_role_map
}

output "setup_complete" {
  value = <<-EOT
  
  ╔═══════════════════════════════════════════════════════════════════════════════╗
  ║              IAM Identity Center - EKS Integration Complete!                  ║
  ╚═══════════════════════════════════════════════════════════════════════════════╝
  
  ✅ EKS Access Entries created for: ${join(", ", keys(aws_eks_access_entry.sso_roles))}
  ✅ RBAC will be deployed by ArgoCD automatically
  
  🔐 To access EKS:
  
  1. Login via SSO:
     aws configure sso
     aws sso login --profile alice-admin
  
  2. Configure kubectl:
     aws eks update-kubeconfig --name ${var.cluster_name} --profile alice-admin --region eu-central-1
  
  3. Test access:
     kubectl get nodes
  
  📚 See docs/IAM-IDENTITY-CENTER-SIMULATION.md for full details
  
  EOT
}
