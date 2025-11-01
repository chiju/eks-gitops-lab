# Create namespace for ArgoCD
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "oci://ghcr.io/argoproj/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  version    = "9.0.5"
}

resource "helm_release" "argocd_apps" {
  name       = "argocd-apps"
  repository = "oci://ghcr.io/argoproj/argo-helm"
  chart      = "argocd-apps"
  namespace  = "argocd"
  
  values = [
    yamlencode({
      applications = {
        app-of-apps = {
          namespace = "argocd"
          finalizers = ["resources-finalizer.argocd.argoproj.io"]
          project = "default"
          source = {
            repoURL        = "https://github.com/chiju/eks-lab-argocd.git"
            targetRevision = "bootstrap"
            path           = "argocd-apps"
          }
          destination = {
            server    = "https://kubernetes.default.svc"
            namespace = "argocd"
          }
          syncPolicy = {
            automated = {
              prune    = true
              selfHeal = true
            }
          }
        }
      }
    })
  ]
  
  depends_on = [helm_release.argocd]
}

resource "kubernetes_secret" "argocd_repo" {
  metadata {
    name      = "eks-lab-argocd-repo"
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = {
    type     = "git"
    url      = "https://github.com/chiju/eks-lab-argocd.git"
    username = var.github_username
    password = var.github_token
  }

  depends_on = [helm_release.argocd]
}