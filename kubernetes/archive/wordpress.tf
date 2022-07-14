# References: 
## https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html
## https://aws.amazon.com/blogs/opensource/kubernetes-ingress-aws-alb-ingress-controller/

# Create IAM OIDC provider: Done

# Create IAM Policy

data "http" "iam-policy-for-aws-loadbalancer-controller" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.1/docs/install/iam_policy.json"
  request_headers = {
    Accept = "application/json"
  }
}

resource "aws_iam_policy" "iam-policy-aws-loadbalancer-controller" {
  name        = "iam-policy-aws-loadbalancer-controller"
  path        = "/"
  description = "iam-policy-aws-loadbalancer-controller"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = data.http.iam-policy-for-aws-loadbalancer-controller.response_body
}

# Create IAM Role

resource "aws_iam_role" "role-aws-loadbalancer-controller" {
  name = "role-aws-loadbalancer-controller"

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
              "${local.eks_openid_provider}:sub" : "system:serviceaccount:kube-system:${var.aws-loadbalancer-sa}"
            }
          }
        }
      ]
    }
  )

}

resource "aws_iam_role_policy_attachment" "aws-lbc-iam-role-policy-attachment" {
  role       = aws_iam_role.role-aws-loadbalancer-controller.name
  policy_arn = aws_iam_policy.iam-policy-aws-loadbalancer-controller.arn
}

# Create Service Account

resource "kubernetes_service_account_v1" "sa-aws-loadbalancer-controller" {
  metadata {
    name      = var.aws-loadbalancer-sa
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.role-aws-loadbalancer-controller.arn
    }
  }
}

# Create Target Group Binding CRD



# Deploy AWS Load Balancer Controller Helm Chart

resource "helm_release" "aws-loadbalancer-controller-chart" {

  depends_on = [kubernetes_service_account_v1.sa-aws-loadbalancer-controller]

  name       = "aws-loadbalancer-controller-chart"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"

  namespace = "kube-system"

  set {
    name  = "clusterName"
    value = data.aws_eks_cluster.m2_eks.name
  }

  set {
    name  = "serviceAccount.create"
    value = false
  }

  set {
    name  = "serviceAccount.name"
    value = var.aws-loadbalancer-sa
  }

  set {
    name  = "image.repository"
    value = "602401143452.dkr.ecr.ap-southeast-1.amazonaws.com/amazon/aws-load-balancer-controller"
  }
}


# Deploy a Sample Nginx App

resource "kubernetes_deployment" "nginx_deploy" {
  metadata {
    name = "nginx-deploy"

    labels = {
      app = "nginx-deploy"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "nginx-deploy"
      }
    }

    template {
      metadata {
        labels = {
          app = "nginx-deploy"
        }
      }

      spec {
        container {
          name  = "nginx"
          image = "nginx"
        }
      }
    }
  }
}

resource "kubernetes_service" "nginx_service" {
  metadata {
    name = "nginx-service"
  }

  spec {
    port {
      name        = "http"
      protocol    = "TCP"
      port        = 80
      target_port = "80"
    }

    selector = {
      app = kubernetes_deployment.nginx_deploy.spec.0.selector.0.match_labels.app
    }

    type = "NodePort"
  }
}

# Deploy Wordpress App
resource "kubernetes_service" "wordpress-service" {
  metadata {
    name = "wordpress-service"
  }
  spec {
    selector = {
      app = kubernetes_deployment.wordpress-deploy.spec.0.selector.0.match_labels.app
    }
    #session_affinity = "ClientIP"
    port {
      port        = 80
      target_port = 80
    }

    type = "LoadBalancer"
  }
}

resource "kubernetes_deployment" "wordpress-deploy" {
  metadata {
    name = "wordpress-deploy"
    labels = {
      app = "wordpress-deploy"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "wordpress-deploy"
      }
    }

    template {
      metadata {
        labels = {
          app = "wordpress-deploy"
        }
      }

      spec {
        container {

          image = "wordpress"
          name  = "wordpress"

          resources {
            limits = {
              cpu    = "1"
              memory = "1Gi"
            }
            requests = {
              cpu    = "250m"
              memory = "50Mi"
            }
          }

          volume_mount {
            name       = "wordpress-volume"
            mount_path = "/var/www/html"
          }

          env {
            name  = "WORDPRESS_DB_HOST"
            value = "mysql-service"
          }

          env {
            name  = "WORDPRESS_DB_USER"
            value = "securedme"
          }

          env {
            name  = "WORDPRESS_DB_PASSWORD"
            value = "securedmepass"
          }

          env {
            name  = "WORDPRESS_DB_NAME"
            value = "magento2db"
          }

        }

        volume {
          name = "wordpress-volume"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.wordpress-pvc.metadata.0.name
          }
        }
      }
    }
  }
}


resource "kubernetes_persistent_volume_claim" "wordpress-pvc" {

  depends_on = [kubernetes_storage_class_v1.efs_storage_class]

  wait_until_bound = false # can't depend on Pod to bound other wise got cycle error

  metadata {
    name = "wordpress-efs-pvc"
  }
  spec {
    access_modes       = ["ReadWriteMany"]
    storage_class_name = "efs-sc"

    resources {
      requests = {
        storage = "10Gi"
      }
    }

  }
}


# Deploy mysql statefulset

data "aws_ssm_parameter" "m2_rds_address" {
  name = "/${var.org}/${var.division}/${var.app}/${terraform.workspace}/m2_rds_address"
}

resource "kubernetes_service" "mysql-service" {
  metadata {
    name = "mysql-service"
  }
  spec {
    type          = "ExternalName"
    external_name = data.aws_ssm_parameter.m2_rds_address.value
  }
}




output "role-aws-loadbalancer-controller" {
  value = aws_iam_role.role-aws-loadbalancer-controller.arn
}

output "iam-policy-aws-loadbalancer-controller" {
  value = aws_iam_policy.iam-policy-aws-loadbalancer-controller.arn
}
