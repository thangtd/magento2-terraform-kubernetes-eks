################################################################################
# LOCAL VARIABLES
################################################################################

locals {
  name                  = "${var.env}-${var.org}-${var.division}-${var.app}"
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

################################################################################
# CSI DRIVER - EFS
################################################################################

data "http" "efs_csi_policy_raw" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-efs-csi-driver/master/docs/iam-policy-example.json"

  # Optional request headers
  request_headers = {
    Accept = "application/json"
  }
}

resource "aws_iam_policy" "efs_csi_driver_policy" {
  name        = "efs-csi-driver-policy"
  path        = "/"
  description = "efs-csi-driver-policy"

  policy = data.http.efs_csi_policy_raw.response_body
}

resource "aws_iam_role" "efs_csi_driver_role" {
  name = "efs-csi-driver-role"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
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
              "${local.eks_openid_provider}:sub" : "system:serviceaccount:${local.controller_namespace}:${var.efs_csi_controller_sa}"
            }
          }
        }
      ]
    }
  )

}

resource "aws_iam_role_policy_attachment" "role_policy_attach_efs_csi" {
  role       = aws_iam_role.efs_csi_driver_role.name
  policy_arn = aws_iam_policy.efs_csi_driver_policy.arn
}

resource "kubernetes_service_account_v1" "efs_csi_service_account" {
  metadata {
    name      = var.efs_csi_controller_sa
    namespace = kubernetes_namespace_v1.controller_namespace.id
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.efs_csi_driver_role.arn
    }
  }

  depends_on = [aws_iam_role_policy_attachment.role_policy_attach_efs_csi]
}

resource "aws_efs_file_system" "efs_for_eks_cluster" {

  creation_token = "${local.name}-efs-for-eks-cluster"

  tags = merge(
    {
      Name = "${local.name}-efs-for-eks-cluster"
    }
  )

  depends_on = [aws_iam_role_policy_attachment.role_policy_attach_efs_csi]
}

resource "aws_efs_access_point" "efs_access_point_eks" {
  file_system_id = aws_efs_file_system.efs_for_eks_cluster.id
}

data "aws_vpc" "eks_vpc" {
  id = var.vpc_id
}

resource "aws_security_group" "efs_sg" {

  name        = "${local.name}-efs-sg"
  description = "EFS SG for mount targets"
  vpc_id      = data.aws_vpc.eks_vpc.id

  ingress {
    description = "TLS from VPC"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.eks_vpc.cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${local.name}-efs-sg"
  }
}

resource "aws_efs_mount_target" "efs_mount_to_private_subnets" {

  for_each  = toset(split(",", var.subnet_ids))
  subnet_id = each.value

  file_system_id = aws_efs_file_system.efs_for_eks_cluster.id

  security_groups = [aws_security_group.efs_sg.id]

}


# Install EBS CSI Driver using HELM
# Resource: Helm Release 
resource "helm_release" "efs_csi_driver" {

  name = "${local.name}-efs-csi-driver"

  namespace       = kubernetes_namespace_v1.controller_namespace.id
  cleanup_on_fail = true
  force_update    = false

  chart = "https://github.com/kubernetes-sigs/aws-efs-csi-driver/releases/download/helm-chart-aws-efs-csi-driver-2.2.7/aws-efs-csi-driver-2.2.7.tgz"

  set {
    name  = "image.repository"
    value = "602401143452.dkr.ecr.ap-southeast-1.amazonaws.com/eks/aws-efs-csi-driver"
  }

  set {
    name  = "controller.serviceAccount.create"
    value = "false"
  }

  set {
    name  = "controller.serviceAccount.name"
    value = kubernetes_service_account_v1.efs_csi_service_account.metadata.0.name
  }

  depends_on = [
    aws_iam_role_policy_attachment.role_policy_attach_efs_csi,
    aws_efs_mount_target.efs_mount_to_private_subnets
  ]

}

resource "kubernetes_storage_class_v1" "efs_storage_class" {

  metadata {
    name = "efs-sc"
  }
  storage_provisioner = "efs.csi.aws.com"
  reclaim_policy      = "Delete"
  volume_binding_mode = "WaitForFirstConsumer"
  parameters = {
    "provisioningMode" = "efs-ap"
    "fileSystemId"     = aws_efs_file_system.efs_for_eks_cluster.id
    "directoryPerms"   = "755"
    "uid"              = "1000"
    "gid"              = "1000"
    "basePath"         = "/dynamic_provisioning"
  }

  depends_on = [
    helm_release.efs_csi_driver,
    aws_efs_mount_target.efs_mount_to_private_subnets,
    aws_efs_access_point.efs_access_point_eks
  ]

}