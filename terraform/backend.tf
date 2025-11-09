terraform {
  backend "s3" {
    bucket  = "eks-lab-argocd-terraform-state"
    key     = "eks-lab/terraform.tfstate"
    region  = "eu-central-1"
    encrypt = true
  }
}
