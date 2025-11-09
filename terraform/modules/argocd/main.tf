resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "oci://ghcr.io/argoproj/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  version    = var.argocd_version
  
  timeout = 600
  
  values = [
    yamlencode({
      configs = {
        cm = {
          "timeout.reconciliation" = "30s"
        }
      }
      controller = {
        tolerations = [{
          key      = "CriticalAddonsOnly"
          operator = "Equal"
          value    = "true"
          effect   = "NoSchedule"
        }]
      }
      server = {
        tolerations = [{
          key      = "CriticalAddonsOnly"
          operator = "Equal"
          value    = "true"
          effect   = "NoSchedule"
        }]
      }
      repoServer = {
        tolerations = [{
          key      = "CriticalAddonsOnly"
          operator = "Equal"
          value    = "true"
          effect   = "NoSchedule"
        }]
      }
      redis = {
        tolerations = [{
          key      = "CriticalAddonsOnly"
          operator = "Equal"
          value    = "true"
          effect   = "NoSchedule"
        }]
      }
      dex = {
        tolerations = [{
          key      = "CriticalAddonsOnly"
          operator = "Equal"
          value    = "true"
          effect   = "NoSchedule"
        }]
      }
      notifications = {
        tolerations = [{
          key      = "CriticalAddonsOnly"
          operator = "Equal"
          value    = "true"
          effect   = "NoSchedule"
        }]
      }
      applicationSet = {
        tolerations = [{
          key      = "CriticalAddonsOnly"
          operator = "Equal"
          value    = "true"
          effect   = "NoSchedule"
        }]
      }
    })
  ]
}

resource "helm_release" "argocd_apps" {
  name       = "argocd-apps"
  repository = "oci://ghcr.io/argoproj/argo-helm"
  chart      = "argocd-apps"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  
  timeout = 600

  values = [
    yamlencode({
      applications = {
        app-of-apps = {
          namespace  = kubernetes_namespace.argocd.metadata[0].name
          finalizers = ["resources-finalizer.argocd.argoproj.io"]
          project    = "default"
          source = {
            repoURL        = var.git_repo_url
            targetRevision = var.git_target_revision
            path           = var.git_apps_path
          }
          destination = {
            server    = "https://kubernetes.default.svc"
            namespace = kubernetes_namespace.argocd.metadata[0].name
          }
          syncPolicy = {
            automated = {
              prune    = true
              selfHeal = true
            }
            syncOptions = [
              "CreateNamespace=true"
            ]
          }
        }
      }
    })
  ]

  depends_on = [helm_release.argocd]
}

resource "kubernetes_secret" "argocd_repo" {
  count = var.github_token != "" ? 1 : 0

  metadata {
    name      = "${var.namespace}-repo"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = {
    type     = "git"
    url      = var.git_repo_url
    username = var.github_username
    password = var.github_token
  }

  depends_on = [helm_release.argocd]
}

