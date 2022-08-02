################################################################################
# EKS - OpenId Indentity Provider
################################################################################
resource "kubernetes_namespace_v1" "monitoring-namespace" {
  metadata {
    name = "monitoring"
  }
}

data "aws_eks_cluster" "magento_eks" {
  name = data.aws_ssm_parameter.magento_ssm_eks_cluster_name.value
}

data "aws_vpc" "eks_vpc" {
  id = data.aws_ssm_parameter.magento_ssm_vpc_id.value
}

data "tls_certificate" "eks_tls_cert" {
  url = data.aws_eks_cluster.magento_eks.identity.0.oidc.0.issuer
}

resource "aws_iam_openid_connect_provider" "eks_identity_provider" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_tls_cert.certificates.0.sha1_fingerprint]
  url             = data.aws_eks_cluster.magento_eks.identity.0.oidc.0.issuer
}
