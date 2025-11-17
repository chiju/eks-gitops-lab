# Complete IAM Identity Center setup with Terraform
# Creates users, permission sets, assignments, and EKS access entries

data "aws_caller_identity" "current" {}
data "aws_ssoadmin_instances" "main" {}

locals {
  instance_arn      = tolist(data.aws_ssoadmin_instances.main.arns)[0]
  identity_store_id = tolist(data.aws_ssoadmin_instances.main.identity_store_ids)[0]
  account_id        = data.aws_caller_identity.current.account_id
}

# Users
resource "aws_identitystore_user" "users" {
  for_each = {
    "alice-admin"  = { display_name = "Alice Admin", email = var.user_email_prefix }
    "bob-devops"   = { display_name = "Bob DevOps", email = var.user_email_prefix }
    "charlie-dev"  = { display_name = "Charlie Developer", email = var.user_email_prefix }
    "diana-viewer" = { display_name = "Diana Viewer", email = var.user_email_prefix }
  }

  identity_store_id = local.identity_store_id
  user_name         = each.key
  display_name      = each.value.display_name

  name {
    given_name  = split(" ", each.value.display_name)[0]
    family_name = split(" ", each.value.display_name)[1]
  }

  emails {
    value   = "${var.user_email_prefix}+${split("-", each.key)[0]}@${var.user_email_domain}"
    primary = true
  }
}

# Permission Sets
resource "aws_ssoadmin_permission_set" "sets" {
  for_each = {
    "PlatformAdmin"  = "arn:aws:iam::aws:policy/AdministratorAccess"
    "DevOpsEngineer" = "arn:aws:iam::aws:policy/PowerUserAccess"
    "Developer"      = "arn:aws:iam::aws:policy/ReadOnlyAccess"
    "ReadOnly"       = "arn:aws:iam::aws:policy/ReadOnlyAccess"
  }

  instance_arn     = local.instance_arn
  name             = each.key
  description      = "Permission set for ${each.key}"
  session_duration = "PT4H"
}

# Attach managed policies to permission sets
resource "aws_ssoadmin_managed_policy_attachment" "policies" {
  for_each = {
    "PlatformAdmin"  = "arn:aws:iam::aws:policy/AdministratorAccess"
    "DevOpsEngineer" = "arn:aws:iam::aws:policy/PowerUserAccess"
    "Developer"      = "arn:aws:iam::aws:policy/ReadOnlyAccess"
    "ReadOnly"       = "arn:aws:iam::aws:policy/ReadOnlyAccess"
  }

  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.sets[each.key].arn
  managed_policy_arn = each.value
}

# Account Assignments (creates SSO roles automatically)
resource "aws_ssoadmin_account_assignment" "assignments" {
  for_each = {
    "alice-admin"  = "PlatformAdmin"
    "bob-devops"   = "DevOpsEngineer"
    "charlie-dev"  = "Developer"
    "diana-viewer" = "ReadOnly"
  }

  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.sets[each.value].arn
  principal_id       = aws_identitystore_user.users[each.key].user_id
  principal_type     = "USER"
  target_id          = local.account_id
  target_type        = "AWS_ACCOUNT"
}

# Query SSO roles (only when enabled)
data "aws_iam_roles" "sso_roles" {
  count       = var.enable_eks_access ? 1 : 0
  name_regex  = "AWSReservedSSO_.*"
  path_prefix = "/aws-reserved/sso.amazonaws.com/"
}

data "aws_iam_role" "sso_role_details" {
  for_each = var.enable_eks_access ? toset(data.aws_iam_roles.sso_roles[0].names) : toset([])
  name     = each.value
}

locals {
  sso_role_map = var.enable_eks_access ? {
    for name, role in data.aws_iam_role.sso_role_details :
    split("_", name)[1] => role.arn
    if length(regexall("^AWSReservedSSO_", name)) > 0
  } : {}

  eks_policies = {
    "PlatformAdmin"  = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
    "DevOpsEngineer" = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
    "Developer"      = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"
    "ReadOnly"       = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
  }
}

resource "aws_eks_access_entry" "sso_roles" {
  for_each = var.enable_eks_access ? {
    for k, v in local.eks_policies :
    k => v
    if contains(keys(local.sso_role_map), k)
  } : {}

  cluster_name  = var.cluster_name
  principal_arn = local.sso_role_map[each.key]
  type          = "STANDARD"

  tags = {
    PermissionSet = each.key
    ManagedBy     = "Terraform"
  }
}

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
