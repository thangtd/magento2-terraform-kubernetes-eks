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

variable "amitype" {
  # Valid values: AL2_x86_64 | AL2_x86_64_GPU | AL2_ARM_64 | CUSTOM | BOTTLEROCKET_ARM_64 | BOTTLEROCKET_x86_64
  description = "AMI Type of EKS Node Group"
  type        = string
  default     = "AL2_x86_64"
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

variable "kube_version" {
  description = "Kubernetes Version"
  type        = string
  default     = "1.21"
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