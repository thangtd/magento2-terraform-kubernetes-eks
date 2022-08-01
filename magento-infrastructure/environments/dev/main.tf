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
      version = "~>4.20.0"
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
