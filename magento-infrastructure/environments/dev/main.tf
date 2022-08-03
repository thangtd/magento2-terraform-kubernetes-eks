# Remote state management
terraform {
  cloud {
    organization = "henrytrantdt"

    workspaces {
      name = "magento-infrastructure-dev"
    }
  }
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>4.24.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~>2.11.0"
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


# Configure the AWS Provider
provider "aws" {
  region              = var.region
  allowed_account_ids = var.allowed_account_ids

  default_tags {
    tags = {
      Workspace = terraform.workspace
      Tool      = "terraform"
    }
  }
}


# Kubernetes Provider
data "aws_eks_cluster_auth" "eks_cluster_auth" {
  name = module.infrastructure.eks_cluster_name
}

provider "kubernetes" {
  host                   = module.infrastructure.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.infrastructure.eks_cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.eks_cluster_auth.token
}

# Heml Provider
provider "helm" {
  kubernetes {
    host                   = module.infrastructure.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(module.infrastructure.eks_cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.eks_cluster_auth.token
  }
}

# kubectl manifest provider
provider "kubectl" {
  host                   = module.infrastructure.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.infrastructure.eks_cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.eks_cluster_auth.token
  load_config_file       = false
}


module "infrastructure" {

  source = "../../modules/infrastructure/"

  bastion_ami     = var.bastion_ami
  org             = var.org
  division        = var.division
  app             = var.app
  env             = var.env
  vpc_cidr        = var.vpc_cidr
  bastion_ssh_key = var.bastion_ssh_key
  ng_ssh_key      = var.ng_ssh_key
  instance_types  = var.instance_types
  capacity_type   = var.capacity_type
  ng_desired_size = var.ng_desired_size
  ng_min_size     = var.ng_min_size
  ng_max_size     = var.ng_max_size
  labels          = var.labels

}

module "kubernetes" {

  source = "../../modules/kubernetes/"

  region                = var.region
  org                   = var.org
  division              = var.division
  app                   = var.app
  env                   = var.env
  eks_cluster_name      = module.infrastructure.eks_cluster_name
  cluster_autoscaler_sa = var.cluster_autoscaler_sa


}
