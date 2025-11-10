# Backend config for local development
# Usage: terraform init -backend-config=../local_setup/backend-local.hcl
bucket       = "eks-lab-argocd-terraform-state"
key          = "eks-lab/terraform.tfstate"
region       = "eu-central-1"
profile      = "oth_infra"
encrypt      = true
use_lockfile = true
