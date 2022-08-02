################################################################################
# MONITORING: METRICS SERVER - PROMETHEUS - GRAFANA
################################################################################
resource "kubernetes_namespace_v1" "monitoring_namespace" {
  metadata {
    name = "monitoring"
  }

  depends_on = [
    aws_eks_node_group.eks_node_group,
    aws_iam_openid_connect_provider.eks_identity_provider
  ]
}

resource "helm_release" "metrics_server" {

  name            = "metrics-server"
  repository      = "https://kubernetes-sigs.github.io/metrics-server/"
  chart           = "metrics-server"
  namespace       = kubernetes_namespace_v1.monitoring_namespace.id
  cleanup_on_fail = true
  force_update    = false

  depends_on = [
    kubernetes_namespace_v1.monitoring_namespace
  ]  

}
