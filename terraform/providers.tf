terraform {
    required_version = ">=1.3"
    required_providers {
        kubernetes = {
            source = "hashicorp/kubernetes"
            version = "~> 2.38"
        }
        helm = {
            source = "hashicorp/helm"
            version = "~> 3.1.0"
        }
    }
}

provider "kubernetes" {
    config_path = "/Users/c.chandran/lab/eks-lab-argocd/terraform/eks-lab-argocd-kubeconfig.yaml"
}

provider "helm" {
    kubernetes = {
        config_path = "/Users/c.chandran/lab/eks-lab-argocd/terraform/eks-lab-argocd-kubeconfig.yaml"
    }
}