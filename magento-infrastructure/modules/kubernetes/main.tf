################################################################################
# LOCAL VARIABLES
################################################################################

locals {
  application_namespace = "${var.env}-${var.app}"
  controller_namespace  = "${var.env}-controller"
  eks_openid_provider   = element(split(":oidc-provider/", aws_iam_openid_connect_provider.eks_identity_provider.arn), 1)
}

################################################################################
# EKS - OpenId Indentity Provider
################################################################################

data "aws_eks_cluster" "magento_eks" {
  name = var.eks_cluster_name
}

data "tls_certificate" "eks_tls_cert" {
  url = data.aws_eks_cluster.magento_eks.identity.0.oidc.0.issuer
}

resource "aws_iam_openid_connect_provider" "eks_identity_provider" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_tls_cert.certificates.0.sha1_fingerprint]
  url             = data.aws_eks_cluster.magento_eks.identity.0.oidc.0.issuer
}

################################################################################
# NAMESPACE
################################################################################

resource "kubernetes_namespace_v1" "controller_namespace" {
  metadata {
    name = local.controller_namespace
  }
}

resource "kubernetes_namespace_v1" "application_namespace" {
  metadata {
    name = local.application_namespace
  }
}

################################################################################
# MONITORING
################################################################################

resource "helm_release" "metrics_server" {

  name            = "metrics-server"
  repository      = "https://kubernetes-sigs.github.io/metrics-server/"
  chart           = "metrics-server"
  namespace       = kubernetes_namespace_v1.controller_namespace.id
  cleanup_on_fail = true
  force_update    = false

}

################################################################################
# CLUSTER AUTOSCALER
################################################################################

resource "aws_iam_policy" "cluster_auto_scale_policy" {
  name        = "cluster_auto_scale_policy"
  path        = "/"
  description = "cluster_auto_scale_policy"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeTags",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplateVersions"
        ],
        "Resource" : ["*"]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          "ec2:DescribeInstanceTypes",
          "eks:DescribeNodegroup"
        ],
        "Resource" : ["*"]
      }
    ]
  })
}

# create aws resource iam role object
resource "aws_iam_role" "cluster_auto_scale_role" {
  name = "cluster_auto_scale_role"
  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Principal" : {
            "Federated" : aws_iam_openid_connect_provider.eks_identity_provider.arn
          },
          "Action" : "sts:AssumeRoleWithWebIdentity",
          "Condition" : {
            "StringEquals" : {
              "${local.eks_openid_provider}:sub" : "system:serviceaccount:${local.controller_namespace}:${var.cluster_autoscaler_sa}"
            }
          }
        }
      ]
    }
  )
}

# attach aws resource iam role policy object to aws resource iam role object
resource "aws_iam_role_policy_attachment" "cluster_auto_scale_role_policy_attachment" {
  role       = aws_iam_role.cluster_auto_scale_role.name
  policy_arn = aws_iam_policy.cluster_auto_scale_policy.arn
}

# aws create kubernetes service account object
resource "kubernetes_service_account_v1" "cluster_auto_scaling_sa" {

  metadata {
    name = var.cluster_autoscaler_sa
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.cluster_auto_scale_role.arn
    }
    namespace = kubernetes_namespace_v1.controller_namespace.id
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_auto_scale_role_policy_attachment
  ]

}

# add helm chart for cluster auto scaler 
resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = "9.19.2"

  namespace = kubernetes_namespace_v1.controller_namespace.id

  cleanup_on_fail = true
  force_update    = false

  set {
    name  = "autoDiscovery.clusterName"
    value = var.eks_cluster_name
  }

  set {
    name  = "awsRegion"
    value = var.region
  }

  set {
    name  = "rbac.serviceAccount.create"
    value = false
  }

  set {
    name  = "rbac.serviceAccount.name"
    value = var.cluster_autoscaler_sa
  }

}