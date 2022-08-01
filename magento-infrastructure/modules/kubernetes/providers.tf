terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~>2.11.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~>4.20.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~>2.6.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }    
  }
}

terraform {
  cloud {
    organization = "henrytrantdt"

    workspaces {
      name = "magento2-kubernetes"
    }
  }
}

data "aws_ssm_parameter" "m2_ssm_eks_cluster_name" {
  name = "/${var.org}/${var.division}/${var.app}/${var.env}/eks_cluster_name"
}

data "aws_ssm_parameter" "m2_ssm_vpc_id" {
  name = "/${var.org}/${var.division}/${var.app}/${var.env}/eks_vpc_id"
}

data "aws_ssm_parameter" "m2_ssm_private_subnets" {
  name = "/${var.org}/${var.division}/${var.app}/${var.env}/eks_private_subnets"
}

data "aws_ssm_parameter" "m2_ssm_public_subnets" {
  name = "/${var.org}/${var.division}/${var.app}/${var.env}/eks_public_subnets"
}

data "aws_eks_cluster" "eks_cluster" {
  name = data.aws_ssm_parameter.m2_ssm_eks_cluster_name.value
}

data "aws_eks_cluster_auth" "eks_cluster_auth" {
  name = data.aws_ssm_parameter.m2_ssm_eks_cluster_name.value
}


# Configure the AWS Provider
provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Workspace = var.env
      Tool      = "terraform"
    }
  }
}


# Terraform Kubernetes Provider
provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks_cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks_cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks_cluster_auth.token
}


provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.eks_cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks_cluster.certificate_authority.0.data)
    token                  = data.aws_eks_cluster_auth.eks_cluster_auth.token
    # exec {
    #   api_version = "client.authentication.k8s.io/v1alpha1"
    #   args        = ["eks", "get-token", "--cluster-name", data.aws_eks_cluster.eks_cluster.name]
    #   command     = "aws"
    # }
  }
}

# kubectl manifest

provider "kubectl" {
  host                   = data.aws_eks_cluster.eks_cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks_cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks_cluster_auth.token  
  load_config_file       = false
}
