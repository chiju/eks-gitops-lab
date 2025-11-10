output "cluster_id" {
  description = "EKS cluster ID"
  value       = aws_eks_cluster.eks_cluster_lrn.id
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.eks_cluster_lrn.name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.eks_cluster_lrn.endpoint
}

output "cluster_certificate_authority_data" {
  description = "EKS cluster certificate authority data"
  value       = aws_eks_cluster.eks_cluster_lrn.certificate_authority[0].data
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA"
  value       = aws_iam_openid_connect_provider.iam_openid_connect_provider_eks_cluster_lrn.arn
}

output "node_group_id" {
  description = "EKS node group ID"
  value       = aws_eks_node_group.system_nodes.id
}

output "grafana_cloudwatch_role_arn" {
  description = "IAM role ARN for Grafana CloudWatch access"
  value       = aws_iam_role.grafana_cloudwatch_role.arn
}

