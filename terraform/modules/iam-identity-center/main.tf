# IAM Identity Center Integration for EKS
# Gets the actual SSO role ARNs created by permission set assignments

data "aws_caller_identity" "current" {}

data "aws_ssoadmin_instances" "main" {}

locals {
  instance_arn      = tolist(data.aws_ssoadmin_instances.main.arns)[0]
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

# Get all IAM roles that match SSO pattern
data "aws_iam_roles" "sso_roles" {
  name_regex  = "AWSReservedSSO_.*"
  path_prefix = "/aws-reserved/sso.amazonaws.com/"
}

# Get details for each SSO role to match with permission sets
data "aws_iam_role" "sso_role_details" {
  for_each = toset(data.aws_iam_roles.sso_roles.names)
  name     = each.value
}

# Map permission set names to actual role ARNs
locals {
  # Extract permission set name from role name (AWSReservedSSO_<PermissionSet>_<random>)
  sso_role_map = {
    for name, role in data.aws_iam_role.sso_role_details :
    split("_", name)[1] => role.arn
    if length(regexall("^AWSReservedSSO_", name)) > 0
  }
}

# EKS Access Entries for SSO roles
resource "aws_eks_access_entry" "sso_roles" {
  for_each = {
    for k, v in local.permission_sets :
    k => v
    if contains(keys(local.sso_role_map), k)
  }

  cluster_name  = var.cluster_name
  principal_arn = local.sso_role_map[each.key]
  type          = "STANDARD"

  tags = {
    PermissionSet = each.key
    ManagedBy     = "Terraform"
  }
}

# EKS Access Policy Associations
resource "aws_eks_access_policy_association" "sso_policies" {
  for_each = aws_eks_access_entry.sso_roles

  cluster_name  = var.cluster_name
  principal_arn = each.value.principal_arn
  policy_arn    = local.permission_sets[each.key].eks_policy

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.sso_roles]
}
