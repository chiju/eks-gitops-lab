# Query existing SSO roles (created by setup-identity-center.sh script)
# This module does NOT create Identity Center resources - run the script first!

data "aws_caller_identity" "current" {}

# Query all SSO roles
data "aws_iam_roles" "sso_roles" {
  name_regex  = "AWSReservedSSO_.*"
  path_prefix = "/aws-reserved/sso.amazonaws.com/"
}

# Get details for each role
data "aws_iam_role" "sso_role_details" {
  for_each = toset(data.aws_iam_roles.sso_roles.names)
  name     = each.value
}

# Map permission set names to role ARNs
locals {
  sso_role_map = {
    for name, role in data.aws_iam_role.sso_role_details :
    split("_", name)[1] => role.arn
    if length(regexall("^AWSReservedSSO_", name)) > 0
  }

  # Map permission sets to EKS policies
  eks_policies = {
    "EKSAdmin"     = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
    "EKSDeveloper" = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"
    "EKSReadOnly"  = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
  }
}

# Create EKS Access Entries for SSO roles
resource "aws_eks_access_entry" "sso_roles" {
  for_each = {
    for k, v in local.eks_policies :
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

# Associate EKS policies
resource "aws_eks_access_policy_association" "sso_policies" {
  for_each = aws_eks_access_entry.sso_roles

  cluster_name  = var.cluster_name
  principal_arn = each.value.principal_arn
  policy_arn    = local.eks_policies[each.key]

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.sso_roles]
}
