# EKS Lab with ArgoCD - Main Configuration
# Deployed via GitHub Actions with OIDC authentication
# Updated: 2025-11-11 - Testing workflow updates

# Account ID validation
data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
}

# Prevent running against wrong account
resource "null_resource" "account_validation" {
  count = local.account_id != var.allowed_account_id ? 1 : 0

  provisioner "local-exec" {
    command = "echo 'ERROR: Terraform is running against account ${local.account_id} but only ${var.allowed_account_id} is allowed' && exit 1"
  }
}

module "vpc" {
  source = "./modules/vpc"

  cluster_name       = var.cluster_name
  cidr               = var.cidr
  availability_zones = var.availability_zones

  depends_on = [null_resource.account_validation]
}

# EKS Module
module "eks" {
  source = "./modules/eks"

  cluster_name            = var.cluster_name
  kubernetes_version      = var.kubernetes_version
  github_actions_role_arn = var.github_actions_role_arn
  public_subnet_ids       = module.vpc.public_subnet_ids
  private_subnet_ids      = module.vpc.private_subnet_ids
  node_instance_type      = var.node_instance_type
  desired_nodes           = var.desired_nodes
  min_nodes               = var.min_nodes
  max_nodes               = var.max_nodes

  depends_on = [module.vpc, null_resource.account_validation]
}

# ArgoCD module - Helm creates namespace automatically
module "argocd" {
  source = "./modules/argocd"

  namespace           = "argocd"
  argocd_version      = "9.1.0"
  git_repo_url        = var.git_repo_url
  git_target_revision = var.git_target_revision
  git_apps_path       = "argocd-apps"
  git_username        = var.git_username
  github_token        = var.github_token

  depends_on = [module.eks, null_resource.account_validation]
}

# IAM Identity Center Integration
# TODO: Add after SSO roles are created via account assignment
# module "iam_identity_center" {
#   source = "./modules/iam-identity-center"
#   
#   cluster_name = var.cluster_name
#   
#   depends_on = [module.eks]
# }
