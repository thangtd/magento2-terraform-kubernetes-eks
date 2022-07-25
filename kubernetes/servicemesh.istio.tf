resource "kubernetes_namespace" "istio_system" {
  metadata {
    annotations = {
      name = "istio-system"
    }

    labels = {
      app = "istio-system"
    }

    name = "istio-system"
  }
}

resource "kubernetes_namespace" "istio_ingress" {
  metadata {
    annotations = {
      name = "istio-ingress"
    }

    labels = {
      app             = "istio-ingress"
      istio-injection = "enabled"
    }

    name = "istio-ingress"
  }
}

resource "helm_release" "istio_base" {
  name       = "istio-base"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "base"

  namespace       = kubernetes_namespace.istio_system.metadata.0.name
  cleanup_on_fail = true
  force_update    = false

}

resource "helm_release" "istio_istiod" {
  name       = "istio-istiod"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istiod"

  namespace       = kubernetes_namespace.istio_system.metadata.0.name
  cleanup_on_fail = true
  force_update    = false

  depends_on = [helm_release.istio_base]

}

# resource "helm_release" "istio_ingress_gateway" {
#   name       = "istio-ingress-gateway"
#   repository = "https://istio-release.storage.googleapis.com/charts"
#   chart      = "gateway"

#   namespace       = kubernetes_namespace.istio_ingress.metadata.0.name
#   cleanup_on_fail = true
#   force_update    = false

#   depends_on = [helm_release.istio_istiod]

# }