terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~>2.11.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~>4.24.0"
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
