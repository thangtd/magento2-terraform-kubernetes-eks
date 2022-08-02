################################################################################
# EKS - OpenId Indentity Provider
################################################################################

data "tls_certificate" "eks_tls_cert" {
  url        = aws_eks_cluster.m2_eks.identity.0.oidc.0.issuer
  depends_on = [aws_eks_node_group.eks_node_group]
}

resource "aws_iam_openid_connect_provider" "eks_identity_provider" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_tls_cert.certificates.0.sha1_fingerprint]
  url             = aws_eks_cluster.m2_eks.identity.0.oidc.0.issuer
  depends_on      = [aws_eks_node_group.eks_node_group]
}
