variable "git_username" {
  description = "GitHub username"
  type        = string
  sensitive   = true
}

variable "github_token" {
  description = "GitHub personal access token"
  type        = string
  sensitive   = true
}

variable "git_repo_url" {
  description = "Git repository URL for ArgoCD"
  type        = string
  default     = "https://github.com/YOUR_USERNAME/eks-gitops-lab.git"
}

variable "git_target_revision" {
  description = "Git branch/tag for ArgoCD to track"
  type        = string
  default     = "main"
}

variable "github_actions_role_arn" {
  description = "ARN of the GitHub Actions role for EKS access"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "eks-gitops-lab"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "allowed_account_id" {
  description = "AWS Account ID that this Terraform is allowed to run against"
  type        = string
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

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.34"
}

variable "node_instance_type" {
  description = "EC2 instance type for nodes"
  type        = string
  default     = "t3.medium"
}

variable "desired_nodes" {
  description = "Desired number of nodes"
  type        = number
  default     = 2
}

variable "min_nodes" {
  description = "Minimum number of nodes"
  type        = number
  default     = 1
}

variable "max_nodes" {
  description = "Maximum number of nodes"
  type        = number
  default     = 3
}
