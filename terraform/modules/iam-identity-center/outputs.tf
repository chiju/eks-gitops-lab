output "instance_arn" {
  description = "IAM Identity Center instance ARN"
  value       = local.instance_arn
}

output "identity_store_id" {
  description = "Identity Store ID"
  value       = local.identity_store_id
}

output "user_ids" {
  description = "Created user IDs"
  value = {
    for k, v in aws_identitystore_user.users : k => v.user_id
  }
}

output "permission_set_arns" {
  description = "Created permission set ARNs"
  value = {
    for k, v in aws_ssoadmin_permission_set.sets : k => v.arn
  }
}

output "sso_roles_found" {
  description = "SSO roles mapped to EKS"
  value       = local.sso_role_map
}

output "setup_complete" {
  value = <<-EOT
  
  ╔═══════════════════════════════════════════════════════════════════════════════╗
  ║              IAM Identity Center - Fully Automated Setup Complete!            ║
  ╚═══════════════════════════════════════════════════════════════════════════════╝
  
  ✅ Users created: ${join(", ", keys(aws_identitystore_user.users))}
  ✅ Permission sets created: ${join(", ", keys(aws_ssoadmin_permission_set.sets))}
  ✅ Account assignments created (SSO roles provisioned)
  ✅ EKS Access Entries created: ${join(", ", keys(aws_eks_access_entry.sso_roles))}
  ✅ RBAC will be deployed by ArgoCD automatically
  
  🔐 To access EKS:
  
  1. Login via SSO:
     aws configure sso
     aws sso login --profile alice-admin
  
  2. Configure kubectl:
     aws eks update-kubeconfig --name ${var.cluster_name} --profile alice-admin --region eu-central-1
  
  3. Test access:
     kubectl get nodes
  
  📧 Users will receive verification emails at:
     ${var.user_email_prefix}+alice@${var.user_email_domain}
     ${var.user_email_prefix}+bob@${var.user_email_domain}
     ${var.user_email_prefix}+charlie@${var.user_email_domain}
     ${var.user_email_prefix}+diana@${var.user_email_domain}
  
  EOT
}
