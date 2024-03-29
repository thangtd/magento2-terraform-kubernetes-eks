variable "allowed_account_ids" {
  description = "AWS Account IDs that can access the infrastructure"
  type        = list(string)
  default     = []
}

variable "region" {
  description = "AWS Region Name"
  type        = string
  default     = ""
}

variable "bastion_ami" {
  description = "AMI ID of the bastion host"
  type        = string
  default     = ""
}

variable "org" {
  description = "Organization Name"
  type        = string
  default     = ""
}

variable "division" {
  description = "Division Name"
  type        = string
  default     = ""
}

variable "app" {
  description = "Application Name"
  type        = string
  default     = ""
}

variable "env" {
  description = "Environment Name"
  type        = string
  default     = ""
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = ""
}

variable "bastion_ssh_key" {
  description = "SSH Key Name for the bastion host"
  type        = string
  default     = ""
}

variable "ng_ssh_key" {
  description = "SSH Key Name for the EKS Node Group"
  type        = string
  default     = ""
}

variable "instance_types" {
  description = "Instance Types of EKS Node Group"
  type        = set(string)
  default     = []
}

variable "capacity_type" {
  description = "Capacity Type of EKS Node Group"
  type        = string
  default     = ""
}

variable "ng_desired_size" {
  description = "Desired Size of the EKS Node Group"
  type        = number
  default     = 0
}

variable "ng_max_size" {
  description = "Max Size of the EKS Node Group"
  type        = number
  default     = 5
}

variable "ng_min_size" {
  description = "Min Size of the EKS Node Group"
  type        = number
  default     = 0
}

variable "labels" {
  description = "A map of labels to apply to contained resources."
  type        = map(string)
  default     = {}
}

variable "cluster_autoscaler_sa" {
  description = "Name of the cluster autoscaler service account"
  type        = string
}

variable "efs_csi_controller_sa" {
  description = "Name of the efs csi controller service account"
  type        = string
}