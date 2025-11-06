module "vpc" {
  source = "./modules/vpc"

  cluster_name       = var.cluster_name
  cidr               = var.cidr
  availability_zones = var.availability_zones
}

# EKS Module
module "eks" {
  source = "./modules/eks"
  
  cluster_name        = var.cluster_name
  kubernetes_version  = var.kubernetes_version
  public_subnet_ids   = module.vpc.public_subnet_ids
  private_subnet_ids  = module.vpc.private_subnet_ids
  node_instance_type  = var.node_instance_type
  desired_nodes       = var.desired_nodes
  min_nodes           = var.min_nodes
  max_nodes           = var.max_nodes

  depends_on = [module.vpc]
}

# ArgoCD module
module "argocd" {
  source = "./modules/argocd"

  namespace            = "argocd"
  argocd_version       = "9.0.5"
  git_repo_url         = "https://github.com/chiju/eks-lab-argocd.git"
  git_target_revision  = "bootstrap"
  git_apps_path        = "argocd-apps"
  github_username      = var.github_username
  github_token         = var.github_token

  depends_on = [module.eks]
}