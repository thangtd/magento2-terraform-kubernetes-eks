
################################################################################
# Test IAM Role for Service Account
################################################################################

resource "aws_iam_policy" "allow_manage_s3_policy" {
  name        = "allow_manage_s3_policy"
  path        = "/"
  description = "Allow pod manage s3 buckets"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode(
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "VisualEditor0",
                "Effect": "Allow",
                "Action": [
                    "s3:*"
                ],
                "Resource": "*"
            }
        ]
    }    
  )
}

resource "aws_iam_role" "allow_manage_s3_role" {

  name = "allow_manage_s3_role"

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
                        "${local.eks_openid_provider}:sub": "system:serviceaccount:default:${local.name}-sa4aws"
                    }
                }
            }
        ]
    }    
  )

}


resource "aws_iam_role_policy_attachment" "role_policy_attach_s3" {
  role       = aws_iam_role.allow_manage_s3_role.name
  policy_arn = aws_iam_policy.allow_manage_s3_policy.arn
}

resource "kubernetes_service_account_v1" "sa4aws" {

  metadata {
    name = "${local.name}-sa4aws"

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.allow_manage_s3_role.arn
    }    

  }

}

resource "kubernetes_pod_v1" "testawscli" {

  metadata {
    name = "testawscli"
  }

  spec {
    service_account_name = kubernetes_service_account_v1.sa4aws.metadata.0.name

    container {
      image = "amazon/aws-cli@sha256:9ad97340e6823e0096c008b17cc6215f6c6c71f6f8f527d405f5b1b152d60bb4"
      image_pull_policy = "IfNotPresent"
      name  = "awscli"
      command = ["sleep", "1d"]
    }

  }
}

