
# create aws resource iam policy object
resource "aws_iam_policy" "cluster_auto_scale_policy" {
  name        = "cluster_auto_scale_policy"
  path        = "/"
  description = "cluster_auto_scale_policy"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeTags",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplateVersions"
        ],
        "Resource": ["*"]
      },
      {
        "Effect": "Allow",
        "Action": [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          "ec2:DescribeInstanceTypes",
          "eks:DescribeNodegroup"
        ],
        "Resource": ["*"]
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
              "${local.eks_openid_provider}:sub" : "system:serviceaccount:kube-system:${var.cluster-auto-scaling-sa}"
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

  depends_on = [
    aws_iam_role_policy_attachment.cluster_auto_scale_role_policy_attachment
  ]

  metadata {
    name = var.cluster-auto-scaling-sa
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.cluster_auto_scale_role.arn
    }
    namespace = "kube-system"
  }
}

# add helm chart for cluster auto scaler 
resource "helm_release" "aws-cluster-autoscaler-controller" {
  name       = "aws-cluster-autoscaler-controller"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = "9.19.2"

  namespace = "kube-system"

  values = [
    "${file("charts/cluster.autoscaler.values.yaml")}"
  ]

  set {
    name  = "autoDiscovery.clusterName"
    value = data.aws_ssm_parameter.m2_ssm_eks_cluster_name.value
  }

  set {
    name  = "awsRegion"
    value = var.region
  }

  set {
    name = "rbac.serviceAccount.create"
    value = false
  }

  set {
    name = "rbac.serviceAccount.name"
    value = var.cluster-auto-scaling-sa
  }

}