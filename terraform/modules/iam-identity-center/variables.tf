variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "user_email_prefix" {
  description = "Email prefix for users (e.g., 'chijuar' for chijuar+alice@gmail.com)"
  type        = string
}

variable "user_email_domain" {
  description = "Email domain for users (e.g., 'gmail.com')"
  type        = string
  default     = "gmail.com"
}

variable "enable_eks_access" {
  description = "Enable EKS access entries (set to true after first apply)"
  type        = bool
  default     = false
}
