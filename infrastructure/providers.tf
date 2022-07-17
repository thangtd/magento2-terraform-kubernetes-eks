terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>4.20.0"
    }
  }
}

terraform {
  cloud {
    organization = "henrytrantdt"

    workspaces {
      name = "magento2-infrastructure"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Workspace = terraform.workspace
      Tool      = "terraform"
    }
  }
}
