
resource "kubernetes_namespace" "argocd" {
  metadata {
    annotations = {
      name = "argocd"
    }
    name = "argocd"
  }
}


resource "helm_release" "helm_argo_cd" {

  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "4.9.8"

  namespace = kubernetes_namespace.argocd.metadata.0.name

  values = [
    "${file("charts/agocd_values.yaml")}"
  ]

}

resource "kubernetes_manifest" "argocd_magento2_app" {

  manifest = {
    "apiVersion" = "argoproj.io/v1alpha1"
    "kind"       = "Application"
    "metadata" = {
      "name"      = "magento2"
      "namespace" = "argocd"
    }
    "spec" = {
      "destination" = {
        "namespace" = "default"
        "server"    = "https://kubernetes.default.svc"
      }
      "project" = "default"
      "source" = {
        "path"           = "kubernetes/markoshust"
        "repoURL"        = "https://github.com/thangtd/magento2-terraform-kubernetes-eks.git"
        "targetRevision" = "HEAD"
      }
      "syncPolicy" = {
        "automated" = {
          "allowEmpty" = false
          "prune"      = true
          "selfHeal"   = true
        }
        "retry" = {
          "backoff" = {
            "duration"    = "5s"
            "factor"      = 2
            "maxDuration" = "3m"
          }
          "limit" = 5
        }
        "syncOptions" = [
          "Validate=false",
          "CreateNamespace=true",
          "PrunePropagationPolicy=foreground",
          "PruneLast=true",
        ]
      }
    }
  }

}

# Get secret
# kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
