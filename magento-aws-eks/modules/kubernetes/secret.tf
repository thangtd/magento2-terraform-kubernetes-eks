# https://www.eksworkshop.com/beginner/194_secrets_manager/
resource "helm_release" "aws_secrets_store_csi_driver" {
  name       = "secrets-store-csi-driver"
  repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart      = "secrets-store-csi-driver"

  namespace = "kube-system"

  set {
    name  = "syncSecret.enabled"
    value = "true"
  }

  set {
    name  = "enableSecretRotation"
    value = "true"
  }

}

resource "kubernetes_service_account" "csi_secrets_store_provider_aws" {
  metadata {
    name      = "csi-secrets-store-provider-aws"
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role" "csi_secrets_store_provider_aws_cluster_role" {
  metadata {
    name = "csi-secrets-store-provider-aws-cluster-role"
  }

  rule {
    verbs      = ["create"]
    api_groups = [""]
    resources  = ["serviceaccounts/token"]
  }

  rule {
    verbs      = ["get"]
    api_groups = [""]
    resources  = ["serviceaccounts"]
  }

  rule {
    verbs      = ["get"]
    api_groups = [""]
    resources  = ["pods"]
  }

  rule {
    verbs      = ["get"]
    api_groups = [""]
    resources  = ["nodes"]
  }
}

resource "kubernetes_cluster_role_binding" "csi_secrets_store_provider_aws_cluster_rolebinding" {
  metadata {
    name = "csi-secrets-store-provider-aws-cluster-rolebinding"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "csi-secrets-store-provider-aws"
    namespace = "kube-system"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "csi-secrets-store-provider-aws-cluster-role"
  }
}

resource "kubernetes_daemonset" "csi_secrets_store_provider_aws" {
  metadata {
    name      = "csi-secrets-store-provider-aws"
    namespace = "kube-system"

    labels = {
      app = "csi-secrets-store-provider-aws"
    }
  }

  spec {
    selector {
      match_labels = {
        app = "csi-secrets-store-provider-aws"
      }
    }

    template {
      metadata {
        labels = {
          app = "csi-secrets-store-provider-aws"
        }
      }

      spec {
        volume {
          name = "providervol"

          host_path {
            path = "/etc/kubernetes/secrets-store-csi-providers"
          }
        }

        volume {
          name = "mountpoint-dir"

          host_path {
            path = "/var/lib/kubelet/pods"
            type = "DirectoryOrCreate"
          }
        }

        container {
          name  = "provider-aws-installer"
          image = "public.ecr.aws/aws-secrets-manager/secrets-store-csi-driver-provider-aws:1.0.r2-6-gee95299-2022.04.14.21.07"
          args  = ["--provider-volume=/etc/kubernetes/secrets-store-csi-providers"]

          resources {
            limits = {
              cpu = "50m"

              memory = "100Mi"
            }

            requests = {
              cpu = "50m"

              memory = "100Mi"
            }
          }

          volume_mount {
            name       = "providervol"
            mount_path = "/etc/kubernetes/secrets-store-csi-providers"
          }

          volume_mount {
            name              = "mountpoint-dir"
            mount_path        = "/var/lib/kubelet/pods"
            mount_propagation = "HostToContainer"
          }

          image_pull_policy = "Always"
        }

        node_selector = {
          "kubernetes.io/os" = "linux"
        }

        service_account_name = "csi-secrets-store-provider-aws"
        host_network         = true
      }
    }

    strategy {
      type = "RollingUpdate"
    }
  }
}

resource "aws_iam_policy" "iam_policy_allow_read_secrets" {
  name        = "iam-policy-allow-read-secrets"
  path        = "/"
  description = "iam-policy-allow-read-secrets"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode(
    {
        "Version": "2012-10-17",
        "Statement": [ {
            "Effect": "Allow",
            "Action": ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"],
            "Resource": ["arn:aws:secretsmanager:ap-southeast-1:336573577202:secret:DBSecret_eksworkshop-EgaW6h"]
        } ]
    }    
  )
}


resource "aws_iam_role" "iam_role_allow_read_secrets" {
  name = "iam-role-allow-read-secrets"

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
              "${local.eks_openid_provider}:sub" : "system:serviceaccount:default:${var.service-account-read-secrets}"
            }
          }
        }
      ]
    }
  )

}

resource "aws_iam_role_policy_attachment" "role_policy_attach_secret_csi" {
  role       = aws_iam_role.iam_role_allow_read_secrets.name
  policy_arn = aws_iam_policy.iam_policy_allow_read_secrets.arn
}

resource "kubernetes_service_account_v1" "service_account_read_secrets" {
  metadata {
    name      = var.service-account-read-secrets
    namespace = "default"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.iam_role_allow_read_secrets.arn
    }
  }

  depends_on = [aws_iam_role_policy_attachment.role_policy_attach_secret_csi]
}

# Testing AWS secret mount
resource "kubectl_manifest" "nginx-deploy-spc" {
  yaml_body = <<YAML
    apiVersion: secrets-store.csi.x-k8s.io/v1alpha1
    kind: SecretProviderClass
    metadata:
      name: nginx-deployment-spc
    spec:
      provider: aws
      parameters:
        objects: |
          - objectName: "DBSecret_eksworkshop"
            objectType: "secretsmanager"
            jmesPath:
              - path: username
                objectAlias: dbusername
              - path: password
                objectAlias: dbpassword
      # Create k8s secret. It requires volume mount first in the pod and then sync.
      secretObjects:                
        - secretName: my-secret-01
          type: Opaque
          data:
            #- objectName: <objectName> or <objectAlias> 
            - objectName: dbusername
              key: db_username_01
            - objectName: dbpassword
              key: db_password_01                
  YAML
}

resource "kubectl_manifest" "nginx_deploy" {
  yaml_body = <<YAML
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: nginx-deployment
      labels:
        app: nginx
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: nginx
      template:
        metadata:
          labels:
            app: nginx
        spec:
          serviceAccountName: service-account-read-secrets
          containers:
          - name: nginx-deployment
            image: nginx
            ports:
            - containerPort: 80
            volumeMounts:
            - name: secrets-store-inline
              mountPath: "/mnt/secrets"
              readOnly: true
            env:
              - name: DB_USERNAME_01
                valueFrom:
                  secretKeyRef:
                    name: my-secret-01
                    key: db_username_01
              - name: DB_PASSWORD_01
                valueFrom:
                  secretKeyRef:
                    name: my-secret-01
                    key: db_password_01              
          volumes:
          - name: secrets-store-inline
            csi:
              driver: secrets-store.csi.k8s.io
              readOnly: true
              volumeAttributes:
                secretProviderClass: nginx-deployment-spc  
  YAML
}