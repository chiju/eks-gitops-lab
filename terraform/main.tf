# module "argocd" {
#   source = "./modules/argocd"

#   namespace            = "argocd"
#   argocd_version       = "9.0.5"
#   git_repo_url         = "https://github.com/chiju/eks-lab-argocd.git"
#   git_target_revision  = "bootstrap"
#   git_apps_path        = "argocd-apps"
#   github_username      = var.github_username
#   github_token         = var.github_token
# }

module "vpc" {
  source = "./modules/vpc"

  cluster_name       = var.cluster_name
  cidr               = var.cidr
  availability_zones = var.availability_zones
}