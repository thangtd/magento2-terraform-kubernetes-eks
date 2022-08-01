locals {
  ES_DOMAIN_NAME  = "eksworkshop-logging"
}

resource "kubernetes_namespace" "logging" {
  metadata {
    annotations = {
      name = "logging"
    }

    name = "logging"
  }
}

resource "aws_iam_policy" "fluent-bit-policy" {
  name        = "fluent-bit-policy"
  path        = "/"
  description = "fluent-bit-policy"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode(
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Action": [
                    "es:ESHttp*"
                ],
                "Resource": "arn:aws:es:${var.region}:${var.account_id}:domain/${local.ES_DOMAIN_NAME}",
                "Effect": "Allow"
            }
        ]
    }    
  )
}


resource "aws_iam_role" "fluent-bit-role" {
  name = "fluent-bit-role"

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
              "${local.eks_openid_provider}:sub" : "system:serviceaccount:${kubernetes_namespace.logging.metadata.0.name}:fluent-bit"
            }
          }
        }
      ]
    }
  )

}

resource "aws_iam_role_policy_attachment" "role-policy-attach-fluent-bit" {
  role       = aws_iam_role.fluent-bit-role.name
  policy_arn = aws_iam_policy.fluent-bit-policy.arn
}

resource "kubernetes_service_account" "sa-fluent-bit" {
  metadata {
    name = "fluent-bit"
    namespace = kubernetes_namespace.logging.metadata.0.name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.fluent-bit-role.arn
    }  
  }
}

resource "aws_elasticsearch_domain" "opensearch-fluent-bit" {

  depends_on = [aws_iam_role_policy_attachment.role-policy-attach-fluent-bit]

  domain_name           = "eksworkshop-logging"
  elasticsearch_version = "OpenSearch_1.0"

  cluster_config {
    instance_type = "t3.medium.elasticsearch"
    instance_count = 1
    dedicated_master_enabled = false
    zone_awareness_enabled = false
    warm_enabled = false
  }

  # access_policies = aws_iam_policy.fluent-bit-policy.policy

  ebs_options {
    ebs_enabled = true
    volume_type = "gp2"
    volume_size = 100
  }

  encrypt_at_rest {
    enabled = true
  }

  node_to_node_encryption {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https = true
    tls_security_policy = "Policy-Min-TLS-1-0-2019-07"
  }

  advanced_security_options {
    enabled = true
    internal_user_database_enabled = true
    master_user_options {
      master_user_name = "eksworkshop"
      master_user_password = "Mt3eNxiuQ9BpjcUg_Ek1$"
    }
  }

  tags = {
    Domain = "eksworkshop-logging"
  }
}