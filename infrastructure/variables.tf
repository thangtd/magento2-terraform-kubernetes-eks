locals {
  name = "${var.org}-${var.division}-${var.app}-${var.env}"
  common_tags = {
    Org = var.org
    Env = var.env
    Div = var.division
    App = var.app
  }

}

variable "region" {
  type = string
}

variable "bastion_ami" {
  type = string
}

variable "org" {
  type = string
}

variable "division" {
  type = string
}

variable "app" {
  type = string
}

variable "env" {
  type = string
}


variable "vpc_cidr" {
  type = string
}

variable "bastion_ssh_key" {
  type = string
}

variable "ng_ssh_key" {
  type = string
}

variable "ami_type" {
  type = string
}

variable "instance_types" {
  type = set(string)
}

variable "capacity_type" {
  type = string
}

variable "kube_version" {
  type = string
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
