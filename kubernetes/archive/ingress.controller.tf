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
                        "${local.eks_openid_provider}:sub": "system:serviceaccount:kube-system:${var.aws-loadbalancer-sa}"
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
    name = var.aws-loadbalancer-sa
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
    name = "image.repository"
    value = "602401143452.dkr.ecr.ap-southeast-1.amazonaws.com/amazon/aws-load-balancer-controller"
  }
}


# Deploy Sample App

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

resource "kubernetes_deployment" "rabbitmq_deploy" {
  metadata {
    name = "rabbitmq-deploy"

    labels = {
      app = "rabbitmq-deploy"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "rabbitmq-deploy"
      }
    }

    template {
      metadata {
        labels = {
          app = "rabbitmq-deploy"
        }
      }

      spec {
        container {
          name  = "rabbitmq"
          image = "rabbitmq:3-management"
        }
      }
    }
  }
}

resource "kubernetes_service" "rabbitmq_service" {
  metadata {
    name = "rabbitmq-service"
  }

  spec {
    port {
      name        = "rmq-admin"
      protocol    = "TCP"
      port        = 15672
      target_port = "15672"
    }

    selector = {
      app = kubernetes_deployment.rabbitmq_deploy.spec.0.selector.0.match_labels.app
    }

    type = "NodePort"
  }
}

# Deploy Ingress Resource
resource "kubernetes_ingress_v1" "aws-loadbalancer-controller-ingress-resource" {

  #depends_on = [helm_release.aws-loadbalancer-controller-chart]

  metadata {
    name = "aws-loadbalancer-controller-ingress-resource"
    annotations = {
      "kubernetes.io/ingress.class" = "alb"
      "alb.ingress.kubernetes.io/scheme" = "internet-facing"
    }
  }

  spec {
    default_backend {
      service {
        name = kubernetes_service.rabbitmq_service.metadata.0.name
        port {
          number = kubernetes_service.rabbitmq_service.spec.0.port.0.port
        }
      }
    }

    rule {
      http {
        path {
          backend {
            service {
              name = kubernetes_service.nginx_service.metadata.0.name
              port {
                number = kubernetes_service.nginx_service.spec.0.port.0.port
              }
            }
          }

          path = "/nginx/*"
        }

        path {
          backend {
            service {
              name = kubernetes_service.rabbitmq_service.metadata.0.name
              port {
                number = kubernetes_service.rabbitmq_service.spec.0.port.0.port
              }
            }
          }

          path = "/rabbitmq/*"
        }
      }
    }
  }
}

