################################################################################
# EKS - OpenId Indentity Provider
################################################################################

data "tls_certificate" "eks_tls_cert" {
  url = aws_eks_cluster.magento_eks.identity.0.oidc.0.issuer
  depends_on = [
    aws_eks_node_group.eks_node_group,
    aws_eks_fargate_profile.magento_fargate_profile
  ]
}

resource "aws_iam_openid_connect_provider" "eks_identity_provider" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_tls_cert.certificates.0.sha1_fingerprint]
  url             = aws_eks_cluster.magento_eks.identity.0.oidc.0.issuer
  depends_on = [
    aws_eks_node_group.eks_node_group,
    aws_eks_fargate_profile.magento_fargate_profile
  ]
}


################################################################################
# MONITORING: METRICS SERVER - PROMETHEUS - GRAFANA
################################################################################
resource "kubernetes_namespace_v1" "monitoring_namespace" {
  metadata {
    name = "monitoring"
  }

  depends_on = [
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

}
