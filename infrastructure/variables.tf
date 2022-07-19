locals {
  name         = "${var.org}-${var.division}-${var.app}-${var.env}"
  cluster_name = "${local.name}-eks"
  common_tags = {
    Org = var.org
    Env = var.env
    Div = var.division
    App = var.app
  }

}

variable "region" {
  type    = string
  default = "ap-southeast-1"
}

variable "bastion_ami" {
  type    = string
  default = "ami-0c802847a7dd848c0"
}

variable "org" {
  type    = string
  default = "org"
}

variable "division" {
  type    = string
  default = "devops"
}

variable "app" {
  type    = string
  default = "m2"
}

variable "env" {
  type    = string
  default = "dev"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "bastion_ssh_key" {
  type    = string
  default = "terraform"
}

variable "ng_ssh_key" {
  type    = string
  default = "terraform"
}

variable "amitype" {
  type    = string
  default = "AL2_ARM_64"
  # Valid values: AL2_x86_64 | AL2_x86_64_GPU | AL2_ARM_64 | CUSTOM | BOTTLEROCKET_ARM_64 | BOTTLEROCKET_x86_64
  # Need to build the docker image differently https://gist.github.com/foo4u/84926426bb9f56166cde4e40efc37b5e
}

variable "instance_types" {
  type    = set(string)
  # memory intensive work load
  default = ["r6g.medium", "r6gd.medium"]
}

variable "capacity_type" {
  type    = string
  default = "SPOT"
}

variable "kube_version" {
  type    = string
  default = "1.21"
}

variable "ng_desired_size" {
  type    = number
  default = 1
}

variable "ng_max_size" {
  type    = number
  default = 5
}

variable "ng_min_size" {
  type    = number
  default = 1
}