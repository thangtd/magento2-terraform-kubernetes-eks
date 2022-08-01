resource "kubernetes_namespace" "amazon-cloudwatch-ns" {
  metadata {
    annotations = {
      name = "amazon-cloudwatch"
    }

    name = "amazon-cloudwatch"
  }
}

resource "aws_iam_role" "role-to-send-metrics-to-cw" {
  name = "role-to-send-metrics-to-cw"

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
              "${local.eks_openid_provider}:sub" : "system:serviceaccount:${kubernetes_namespace.amazon-cloudwatch-ns.metadata.0.name}:${var.amazon-cloudwatch-sa}"
            }
          }
        }
      ]
    }
  )

}

resource "aws_iam_role_policy_attachment" "role-policy-attach-cloudwatch-log" {
  role       = aws_iam_role.role-to-send-metrics-to-cw.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}


resource "kubernetes_service_account_v1" "cloudwatch_log_sa" {
  metadata {
    name      = var.amazon-cloudwatch-sa
    namespace = kubernetes_namespace.amazon-cloudwatch-ns.metadata.0.name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.role-to-send-metrics-to-cw.arn
    }
  }

  depends_on = [aws_iam_role_policy_attachment.role-policy-attach-cloudwatch-log]
}

resource "kubernetes_cluster_role" "cloudwatch-agent-role" {
  metadata {
    name = "cloudwatch-agent-role"
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "nodes", "endpoints"]
    verbs      = ["list", "watch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["replicasets"]
    verbs      = ["list", "watch"]
  }

  rule {
    api_groups = ["batch"]
    resources  = ["jobs"]
    verbs      = ["list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["nodes/proxy"]
    verbs      = ["get"]
  }

  rule {
    api_groups = [""]
    resources  = ["nodes/stats", "configmaps", "events"]
    verbs      = ["create"]
  }

  rule {
    api_groups     = [""]
    resources      = ["configmaps"]
    resource_names = ["cwagent-clusterleader"]
    verbs          = ["get", "update"]
  }

}

resource "kubernetes_cluster_role_binding" "cloudwatch-agent-role-binding" {
  metadata {
    name = "cloudwatch-agent-role-binding"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.cloudwatch-agent-role.metadata.0.name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.cloudwatch_log_sa.metadata.0.name
    namespace = kubernetes_namespace.amazon-cloudwatch-ns.metadata.0.name
  }
}

resource "kubernetes_config_map" "cwagentconfig" {
  metadata {
    name      = "cwagentconfig"
    namespace = kubernetes_namespace.amazon-cloudwatch-ns.metadata.0.name
  }

  data = {
    "cwagentconfig.json" = <<EOF
        {
          "logs": {
            "metrics_collected": {
              "kubernetes": {
                "cluster_name": "${data.aws_ssm_parameter.m2_ssm_eks_cluster_name.value}",
                "metrics_collection_interval": 60
              }
            },
            "force_flush_interval": 5
          }
        }
        EOF
  }

}

resource "kubernetes_daemonset" "cloudwatch_agent" {
  metadata {
    name      = "cloudwatch-agent"
    namespace = kubernetes_namespace.amazon-cloudwatch-ns.metadata.0.name
  }

  spec {
    selector {
      match_labels = {
        name = "cloudwatch-agent"
      }
    }

    template {
      metadata {
        labels = {
          name = "cloudwatch-agent"
        }
      }

      spec {
        volume {
          name = "cwagentconfig"

          config_map {
            name = kubernetes_config_map.cwagentconfig.metadata.0.name
          }
        }

        volume {
          name = "rootfs"

          host_path {
            path = "/"
          }
        }

        volume {
          name = "dockersock"

          host_path {
            path = "/var/run/docker.sock"
          }
        }

        volume {
          name = "varlibdocker"

          host_path {
            path = "/var/lib/docker"
          }
        }

        volume {
          name = "containerdsock"

          host_path {
            path = "/run/containerd/containerd.sock"
          }
        }

        volume {
          name = "sys"

          host_path {
            path = "/sys"
          }
        }

        volume {
          name = "devdisk"

          host_path {
            path = "/dev/disk/"
          }
        }

        container {
          name  = "cloudwatch-agent"
          image = "amazon/cloudwatch-agent:1.247352.0b251908"

          env {
            name = "HOST_IP"

            value_from {
              field_ref {
                field_path = "status.hostIP"
              }
            }
          }

          env {
            name = "HOST_NAME"

            value_from {
              field_ref {
                field_path = "spec.nodeName"
              }
            }
          }

          env {
            name = "K8S_NAMESPACE"

            value_from {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }

          env {
            name  = "CI_VERSION"
            value = "k8s/1.3.10"
          }

          resources {
            limits = {
              cpu = "200m"

              memory = "200Mi"
            }

            requests = {
              cpu = "200m"

              memory = "200Mi"
            }
          }

          volume_mount {
            name       = "cwagentconfig"
            mount_path = "/etc/cwagentconfig"
          }

          volume_mount {
            name       = "rootfs"
            read_only  = true
            mount_path = "/rootfs"
          }

          volume_mount {
            name       = "dockersock"
            read_only  = true
            mount_path = "/var/run/docker.sock"
          }

          volume_mount {
            name       = "varlibdocker"
            read_only  = true
            mount_path = "/var/lib/docker"
          }

          volume_mount {
            name       = "containerdsock"
            read_only  = true
            mount_path = "/run/containerd/containerd.sock"
          }

          volume_mount {
            name       = "sys"
            read_only  = true
            mount_path = "/sys"
          }

          volume_mount {
            name       = "devdisk"
            read_only  = true
            mount_path = "/dev/disk"
          }
        }

        termination_grace_period_seconds = 60
        service_account_name             = var.amazon-cloudwatch-sa
      }
    }
  }
}
