variable "eks_cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID of the EKS cluster"
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "Subnet IDs of the EKS cluster"
  type        = string
  default     = ""
}

variable "cluster_autoscaler_sa" {
  description = "Name of the cluster autoscaler service account"
  type        = string
}

variable "efs_csi_controller_sa" {
  description = "Name of the efs csi controller service account"
  type        = string
}

variable "region" {
  description = "AWS Region Name"
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
