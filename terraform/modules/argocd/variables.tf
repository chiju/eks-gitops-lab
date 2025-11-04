variable "namespace" {
  description = "Kubernetes namespace for ArgoCD"
  type        = string
  default     = "argocd"
}

variable "argocd_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "9.0.5"
}

variable "git_repo_url" {
  description = "Git repository URL"
  type        = string
}

variable "git_target_revision" {
  description = "Git branch/tag"
  type        = string
  default     = "main"
}

variable "git_apps_path" {
  description = "Path to ArgoCD applications in repo"
  type        = string
  default     = "argocd-apps"
}

variable "github_username" {
  description = "GitHub username for private repos"
  type        = string
  default     = ""
}

variable "github_token" {
  description = "GitHub token for private repos"
  type        = string
  default     = ""
  sensitive   = true
}
