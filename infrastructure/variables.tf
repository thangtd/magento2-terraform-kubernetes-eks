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

variable "ami_type" {
  type    = string
  default = "AL2_x86_64"
}

variable "instance_types" {
  type    = set(string)
  default = ["t2.medium", "t3.medium"]
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
  default = 3
}

variable "ng_min_size" {
  type    = number
  default = 1
}