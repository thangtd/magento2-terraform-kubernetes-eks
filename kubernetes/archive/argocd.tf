
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
    "${file("charts/agocd.values.yaml")}"
  ]

}

resource "kubernetes_manifest" "argocd_magento2_app" {

  depends_on = [helm_release.helm_argo_cd]

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
        "path"           = "kubernetes/manifest"
        "repoURL"        = "https://github.com/thangtd/magento2-terraform-kubernetes-eks.git"
        "targetRevision" = "HEAD"
      }
    }
  }

}

# Get secret
# kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
