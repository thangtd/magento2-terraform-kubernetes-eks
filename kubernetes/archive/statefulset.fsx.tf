resource "aws_iam_role" "fsx_csi_driver_role" {
  name = "fsx_csi_driver_role"

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
              "${local.eks_openid_provider}:sub" : "system:serviceaccount:kube-system:${var.fsx_csi_service_account}"
            }
          }
        }
      ]
    }
  )

}

resource "aws_iam_role_policy_attachment" "role_policy_attach_fsx_csi" {
  role       = aws_iam_role.fsx_csi_driver_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonFSxFullAccess"
}


resource "kubernetes_service_account_v1" "fsx_csi_service_account" {

  metadata {
    name = var.fsx_csi_service_account
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.fsx_csi_driver_role.arn
    }
    namespace = "kube-system"
  }

}

resource "helm_release" "aws_fsx_csi_driver" {

  name  = "aws-fsx-csi-driver"
  chart = "https://github.com/kubernetes-sigs/aws-fsx-csi-driver/releases/download/helm-chart-aws-fsx-csi-driver-1.4.2/aws-fsx-csi-driver-1.4.2.tgz"

  namespace = "kube-system"

  set {
    name  = "controller.replicaCount"
    value = 1
  }

  set {
    name  = "controller.serviceAccount.create"
    value = "false"
  }

  set {
    name  = "controller.serviceAccount.name"
    value = kubernetes_service_account_v1.fsx_csi_service_account.metadata.0.name
  }

}



resource "aws_security_group" "fsx_sg" {

  depends_on = [helm_release.aws_fsx_csi_driver]

  name        = "fsx_sg"
  description = "Fsx SG"
  vpc_id      = data.aws_vpc.eks_vpc.id

  ingress {
    description     = "Allows Lustre traffic between FSx for Lustre file servers"
    from_port       = 988
    to_port         = 988
    protocol        = "tcp"
    security_groups = [data.aws_eks_cluster.eks_cluster.vpc_config.0.cluster_security_group_id]
  }

  ingress {
    description     = "Allows Lustre traffic between FSx for Lustre file servers"
    from_port       = 1021
    to_port         = 1023
    protocol        = "tcp"
    security_groups = [data.aws_eks_cluster.eks_cluster.vpc_config.0.cluster_security_group_id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${local.name}_fsx_sg"
  }
}

resource "kubernetes_storage_class_v1" "fsx-sc" {
  metadata {
    name = "fsx-sc"
  }
  storage_provisioner = "fsx.csi.aws.com"
  reclaim_policy      = "Delete"
  parameters = {
    subnetId         = element(split(",", nonsensitive(data.aws_ssm_parameter.m2_ssm_private_subnets.value)), 0)
    securityGroupIds = aws_security_group.fsx_sg.id
    deploymentType   = "PERSISTENT_1"
    perUnitStorageThroughput = "100"
  }
  mount_options = ["flock"]
}

resource "kubernetes_persistent_volume_claim_v1" "fsx-claim" {
  metadata {
    name = "fsx-claim"
  }
  spec {
    access_modes       = ["ReadWriteMany"]
    storage_class_name = kubernetes_storage_class_v1.fsx-sc.metadata.0.name
    resources {
      requests = {
        storage = "1200Gi"
      }
    }
  }
}
