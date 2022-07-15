
data "http" "ebs_csi_policy_raw" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-ebs-csi-driver/master/docs/example-iam-policy.json"

  # Optional request headers
  request_headers = {
    Accept = "application/json"
  }
}

# AWS CSI
# https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html

resource "aws_iam_policy" "aws_ebs_csi_driver_policy" {
  name        = "aws_ebs_csi_driver_policy"
  path        = "/"
  description = "aws_ebs_csi_driver_policy"

  policy = data.http.ebs_csi_policy_raw.response_body
}

resource "aws_iam_role" "aws_ebs_csi_driver_role" {
  name = "aws_ebs_csi_driver_role"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode(
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Federated": aws_iam_openid_connect_provider.eks_identity_provider.arn
                },
                "Action": "sts:AssumeRoleWithWebIdentity",
                "Condition": {
                    "StringEquals": {
                        "${local.eks_openid_provider}:sub": "system:serviceaccount:kube-system:${var.ebs-csi-controller-sa}"
                    }
                }
            }
        ]
    }        
  )

}

resource "aws_iam_role_policy_attachment" "role_policy_attach_ebs_csi" {
  role       = aws_iam_role.aws_ebs_csi_driver_role.name
  policy_arn = aws_iam_policy.aws_ebs_csi_driver_policy.arn
}

# Install EBS CSI Driver using HELM
# Resource: Helm Release 
resource "helm_release" "ebs_csi_driver" {
  depends_on = [aws_iam_role_policy_attachment.role_policy_attach_ebs_csi]
  name       = "${local.name}-aws-ebs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  namespace = "kube-system"     

  set {
    name = "image.repository"
    value = "602401143452.dkr.ecr.ap-southeast-1.amazonaws.com/eks/aws-ebs-csi-driver"
  }       

  set {
    name  = "controller.serviceAccount.create"
    value = "true"
  }

  set {
    name  = "controller.serviceAccount.name"
    value = var.ebs-csi-controller-sa
  }

  set {
    name  = "controller.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = "${aws_iam_role.aws_ebs_csi_driver_role.arn}"
  }
    
}

# Create EBS Storage Class
resource "kubernetes_storage_class_v1" "mysql_gp2" {
  metadata {
    name = "mysql-gp2"
  }
  storage_provisioner = "ebs.csi.aws.com"
  reclaim_policy      = "Delete"
  parameters = {
    type = "gp2"
    encrypted = "true"
  }
  volume_binding_mode = "WaitForFirstConsumer"
  mount_options = ["debug"]

  depends_on = [helm_release.ebs_csi_driver,kubernetes_namespace_v1.mysql-namespace]

}


# MYSQL App

resource "kubernetes_namespace_v1" "mysql-namespace" {
  metadata {
    name = "mysql"
  }
}

resource "kubernetes_config_map_v1" "mysql_config" {
  metadata {
    name = "mysql-config"
    namespace = kubernetes_namespace_v1.mysql-namespace.metadata.0.name
    labels = {
      app = "mysql"
    }
  }

  data = {
    "master.cnf" = <<EOF
          [mysqld]
          log-bin
        EOF
    "slave.cnf" = <<EOF
          [mysqld]
          super-read-only
        EOF
  }

}

# Create Headless mysql service for write data
resource "kubernetes_service_v1" "mysql" {
  metadata {
    name = "mysql"
    namespace = kubernetes_namespace_v1.mysql-namespace.metadata.0.name
    labels = {
      app = "mysql"
    }
  }
  spec {

    selector = {
      app = "mysql"
    }

    cluster_ip = "None"

    port {
        name = "mysql"
        port = 3306
    }

  }

  depends_on = [kubernetes_manifest.mysql_statefulset]
}

# Create ClusterIp service for mysql read
resource "kubernetes_service_v1" "mysql-read" {
  metadata {
    name = "mysql-read"
    namespace = kubernetes_namespace_v1.mysql-namespace.metadata.0.name
    labels = {
      app = "mysql"
    }
  }
  spec {

    selector = {
      app = "mysql"
    }

    port {
      name = "mysql"
      port = 3306
    }

  }

  depends_on = [kubernetes_manifest.mysql_statefulset]
}

resource "kubernetes_manifest" "mysql_statefulset" {
  manifest = yamldecode(file("${path.module}/manifests/mysql-statefulset.yaml"))
  depends_on = [kubernetes_config_map_v1.mysql_config, kubernetes_namespace_v1.mysql-namespace]
}