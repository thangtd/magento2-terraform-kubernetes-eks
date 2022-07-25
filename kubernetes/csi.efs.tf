data "http" "efs_csi_policy_raw" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-efs-csi-driver/master/docs/iam-policy-example.json"

  # Optional request headers
  request_headers = {
    Accept = "application/json"
  }
}


resource "aws_iam_policy" "efs_csi_driver_policy" {
  name        = "efs_csi_driver_policy"
  path        = "/"
  description = "efs_csi_driver_policy"

  policy = data.http.efs_csi_policy_raw.response_body
}

resource "aws_iam_role" "efs_csi_driver_role" {
  name = "efs_csi_driver_role"

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
              "${local.eks_openid_provider}:sub" : "system:serviceaccount:kube-system:${var.efs-csi-controller-sa}"
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
    name      = var.efs-csi-controller-sa
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.efs_csi_driver_role.arn
    }
  }

  depends_on = [aws_iam_role_policy_attachment.role_policy_attach_efs_csi]
}


# Install EBS CSI Driver using HELM
# Resource: Helm Release 
resource "helm_release" "efs_csi_driver" {

  depends_on = [
    aws_iam_role_policy_attachment.role_policy_attach_efs_csi,
    kubernetes_service_account_v1.efs_csi_service_account,
    aws_efs_mount_target.efs_mount_to_private_subnets
  ]

  name = "${local.name}-efs-csi-driver"

  namespace       = "kube-system"
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

}

resource "aws_efs_file_system" "efs_demo" {

  depends_on = [aws_iam_role_policy_attachment.role_policy_attach_efs_csi]

  creation_token = "${local.name}-efs-demo"

  tags = merge(
    {
      Name = "${local.name}-efs-demo"
    }
  )
}

resource "aws_efs_access_point" "efs_access_point_demo" {
  file_system_id = aws_efs_file_system.efs_demo.id
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

  #for_each  = toset(split(",", nonsensitive(data.aws_ssm_parameter.m2_ssm_private_subnets.value)))
  for_each  = toset(split(",", nonsensitive(data.aws_ssm_parameter.m2_ssm_public_subnets.value)))
  subnet_id = each.value

  file_system_id = aws_efs_file_system.efs_demo.id

  security_groups = [aws_security_group.efs_sg.id]
}

resource "kubernetes_storage_class_v1" "efs_storage_class" {

  depends_on = [
    helm_release.efs_csi_driver,
    aws_efs_mount_target.efs_mount_to_private_subnets,
    aws_efs_access_point.efs_access_point_demo
  ]

  metadata {
    name = "efs-sc"
  }
  storage_provisioner = "efs.csi.aws.com"
  reclaim_policy      = "Delete"
  volume_binding_mode = "WaitForFirstConsumer"
  parameters = {
    "provisioningMode" = "efs-ap"
    "fileSystemId"     = aws_efs_file_system.efs_demo.id
    "directoryPerms"   = "755"
    "uid"              = "1000"
    "gid"              = "1000"
    "basePath"         = "/dynamic_provisioning"
  }

}

output "efs_csi_driver_role" {
  value = aws_iam_role.efs_csi_driver_role.arn
}

output "efs_csi_driver_policy" {
  value = aws_iam_policy.efs_csi_driver_policy.arn
}

output "efs_sg_id" {
  value = aws_security_group.efs_sg.id
}

output "efs-file-system-id" {
  value = aws_efs_file_system.efs_demo.id
}
