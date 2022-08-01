resource "kubernetes_namespace" "product_catalog_ns" {
  metadata {
    name = "prodcatalog-ns"
  }
}

resource "kubernetes_namespace" "amazon_cloudwatch" {
  metadata {
    name = "amazon-cloudwatch"
  }
}

data "aws_iam_role" "magento_eks_fargate_role" {
  name = "magento-eks-fargate-role"
}

resource "kubernetes_service_account_v1" "envoy_proxy_sa" {
  metadata {
    name      = "prodcatalog-envoy-proxies"
    namespace = kubernetes_namespace.product_catalog_ns.metadata.0.name
    annotations = {
      "eks.amazonaws.com/role-arn" = data.aws_iam_role.magento_eks_fargate_role.arn
    }
  }
}


# Enable Amazon Cloudwatch Container Insights

resource "kubernetes_service_account_v1" "cloudwatch_agent" {
  metadata {
    name      = "cloudwatch-agent"
    namespace = kubernetes_namespace.amazon_cloudwatch.metadata.0.name
    annotations = {
      "eks.amazonaws.com/role-arn" = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
    }
  }
}

resource "kubernetes_service_account_v1" "fluentd" {
  metadata {
    name      = "fluentd"
    namespace = kubernetes_namespace.amazon_cloudwatch.metadata.0.name
    annotations = {
      "eks.amazonaws.com/role-arn" = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
    }
  }
}

# resource "kubernetes_manifest" "aws_cwagent_fluentd" {
#   manifest   = yamldecode(file("${path.module}/manifests/cwagent-fluentd-quickstart.yaml"))
#   depends_on = [kubernetes_service_account_v1.fluentd]
# }


# resource "kubectl_manifest" "aws_cwagent_fluentd" {
#     yaml_body = file("${path.module}/manifests/cwagent-fluentd-quickstart.yaml")
# }

# Enable Prometheus
resource "kubernetes_service_account_v1" "cwagent_prometheus" {
  metadata {
    name      = "cwagent-prometheus"
    namespace = kubernetes_namespace.amazon_cloudwatch.metadata.0.name
    annotations = {
      "eks.amazonaws.com/role-arn" = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy "
    }
  }
}

# resource "kubernetes_manifest" "prometheus_eks" {
#   manifest   = yamldecode(file("${path.module}/manifests/prometheus-eks.yaml"))
#   depends_on = [kubernetes_service_account_v1.cwagent_prometheus]
# }

# resource "kubectl_manifest" "prometheus_eks" {
#     yaml_body = file("${path.module}/manifests/prometheus-eks.yaml")
# }

# Enable Logging for Fargate
resource "kubernetes_namespace" "aws_observability" {
  metadata {
    name = "aws-observability"
  }
}

resource "kubernetes_config_map" "aws_logging" {
  metadata {
    name      = "aws-logging"
    namespace = kubernetes_namespace.aws_observability.metadata.0.name
  }

  data = {
    "output.conf" = <<EOF
    [OUTPUT]
        Name cloudwatch_logs
        Match   *
        region ap-southeast-1
        log_group_name fluent-bit-cloudwatch
        log_stream_prefix from-fluent-bit-
        auto_create_group true
        EOF
  }

}

data "http" "fluent_bit_eks_fargate_raw_policy" {
  url = "https://raw.githubusercontent.com/aws-samples/amazon-eks-fluent-logging-examples/mainline/examples/fargate/cloudwatchlogs/permissions.json"

  # Optional request headers
  request_headers = {
    Accept = "application/json"
  }
}


resource "aws_iam_policy" "fluent_bit_eks_fargate_policy" {
  name        = "fluent-bit-eks-fargate"
  path        = "/"
  description = "fluent-bit-eks-fargate"

  policy = data.http.fluent_bit_eks_fargate_raw_policy.response_body
}


resource "aws_iam_role_policy_attachment" "fluent_bit_eks_fargate_policy_role_attachment" {
  role       = data.aws_iam_role.magento_eks_fargate_role.name
  policy_arn = aws_iam_policy.fluent_bit_eks_fargate_policy.arn
}