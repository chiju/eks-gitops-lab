# S3 backend with native state locking (no DynamoDB needed)
# Fresh deployment: 2025-11-09
terraform {
  backend "s3" {
    bucket       = "eks-lab-argocd-terraform-state"
    key          = "eks-lab/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
  }
}
