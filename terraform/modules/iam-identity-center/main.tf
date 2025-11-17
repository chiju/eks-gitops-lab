# IAM Identity Center Integration for EKS
# Users and permission sets are created by bootstrap script
# This module only creates EKS Access Entries

data "aws_caller_identity" "current" {}

data "aws_ssoadmin_instances" "main" {}

locals {
  instance_arn = tolist(data.aws_ssoadmin_instances.main.arns)[0]
  identity_store_id = tolist(data.aws_ssoadmin_instances.main.identity_store_ids)[0]
  
  # Permission sets created by bootstrap script
  permission_sets = {
    "PlatformAdmin" = {
      eks_policy = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
    }
    "DevOpsEngineer" = {
      eks_policy = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
    }
    "Developer" = {
      eks_policy = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"
    }
    "ReadOnly" = {
      eks_policy = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
    }
  }
}

# Get permission set ARNs
data "aws_ssoadmin_permission_set" "sets" {
  for_each = local.permission_sets
  
  instance_arn = local.instance_arn
  name         = each.key
}

# EKS Access Entries for SSO roles
# SSO creates roles with pattern: AWSReservedSSO_<PermissionSetName>_<random>
resource "aws_eks_access_entry" "sso_roles" {
  for_each = local.permission_sets
  
  cluster_name  = var.cluster_name
  # Wildcard to match SSO-created roles
  principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-reserved/sso.amazonaws.com/*/AWSReservedSSO_${each.key}_*"
  type          = "STANDARD"
  
  tags = {
    PermissionSet = each.key
    ManagedBy     = "Terraform"
  }
}

# EKS Access Policy Associations
resource "aws_eks_access_policy_association" "sso_policies" {
  for_each = local.permission_sets
  
  cluster_name  = var.cluster_name
  principal_arn = aws_eks_access_entry.sso_roles[each.key].principal_arn
  policy_arn    = each.value.eks_policy
  
  access_scope {
    type = "cluster"
  }
  
  depends_on = [aws_eks_access_entry.sso_roles]
}
