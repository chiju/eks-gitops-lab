# variable "github_username" {
#   description = "GitHub username"
#   type        = string
#   sensitive   = true
# }

# variable "github_token" {
#   description = "GitHub personal access token"
#   type        = string
#   sensitive   = true
# }

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "eks-lab-argocd"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["eu-central-1a", "eu-central-1b"]
}
