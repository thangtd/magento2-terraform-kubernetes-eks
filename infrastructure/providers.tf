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
  region = var.region
  default_tags {
    tags = {
      Workspace = terraform.workspace
      Tool      = "terraform"
    }
  }
}
