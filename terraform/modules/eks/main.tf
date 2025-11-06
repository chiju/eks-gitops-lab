# EKS Cluster IAM Role
resource "aws_iam_role" "iam_role_eks_lrn" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${var.cluster_name}-cluster-role"
  }
}

# Attach required policy to cluster role
resource "aws_iam_role_policy_attachment" "iam_role_policy_attachment_eks_policy_lrn" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.iam_role_eks_lrn.name
}

# EKS Cluster
resource "aws_eks_cluster" "eks_cluster_lrn" {
  name = var.cluster_name
  role_arn = aws_iam_role.iam_role_eks_lrn.arn
  version = var.kubernetes_version
  vpc_config {
    subnet_ids = concat(var.public_subnet_ids, var.private_subnet_ids)
    endpoint_private_access = true
    endpoint_public_access = true
  }
  depends_on = [ 
    aws_iam_role_policy_attachment.iam_role_policy_attachment_eks_policy_lrn
   ]
  tags = {
    Name = var.cluster_name
  }
}

# Get OIDC provider certificate
data "tls_certificate" "tls_certificate_eks_cluster_lrn" {
  url = aws_eks_cluster.eks_cluster_lrn.identity[0].oidc[0].issuer
}

# OIDC Provider for IRSA
resource "aws_iam_openid_connect_provider" "iam_openid_connect_provider_eks_cluster_lrn" {
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.tls_certificate_eks_cluster_lrn.certificates[0].sha1_fingerprint]
  url = aws_eks_cluster.eks_cluster_lrn.identity[0].oidc[0].issuer
  tags = {
    Name = "${var.cluster_name}-oidc-provider"
  }
}

# Node Group IAM Role
resource "aws_iam_role" "iam_role_node_group_lrn" {
  name = "${var.cluster_name}-node-group-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
  tags = {
    Name = "${var.cluster_name}-node-group-role"
  }
}

# Attach required policies to node group role
resource "aws_iam_role_policy_attachment" "iam_role_policy_attachment_node_group_lrn" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  ])

  policy_arn = each.value
  role       = aws_iam_role.iam_role_node_group_lrn.name
}

# EKS Node Group
resource "aws_eks_node_group" "eks_node_group_lrn" {
  cluster_name    = aws_eks_cluster.eks_cluster_lrn.name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = aws_iam_role.iam_role_node_group_lrn.arn
  subnet_ids      = var.private_subnet_ids

  scaling_config {
    desired_size = var.desired_nodes
    max_size     = var.max_nodes
    min_size     = var.min_nodes
  }

  instance_types = [var.node_instance_type]

  depends_on = [
    aws_iam_role_policy_attachment.iam_role_policy_attachment_node_group_lrn
  ]

  tags = {
    Name = "${var.cluster_name}-node-group"
  }
}