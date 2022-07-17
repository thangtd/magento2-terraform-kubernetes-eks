locals {
  name                = "${var.app}-${var.env}"
  namespace           = local.name
  eks_openid_provider = element(split(":oidc-provider/", aws_iam_openid_connect_provider.eks_identity_provider.arn), 1)
}

variable "region" {
  type    = string
  default = "ap-southeast-1"
}

variable "account_id" {
  type    = string
  default = "336573577202"
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

variable "ebs-csi-controller-sa" {
  type    = string
  default = "ebs-csi-controller-sa"
}

variable "fsx_csi_service_account" {
  type    = string
  default = "fsx-csi-controller-sa"
}

variable "efs-csi-controller-sa" {
  type    = string
  default = "efs-csi-controller-sa"
}

variable "amazon-cloudwatch-sa" {
  type    = string
  default = "amazon-cloudwatch"
}

variable "aws-loadbalancer-sa" {
  type    = string
  default = "aws-load-balancer-controller"
}

variable "cluster-auto-scaling-sa" {
  type    = string
  default = "cluster-auto-scaling-controller"
}