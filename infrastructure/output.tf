output "vpc_id" {
  value = aws_vpc.m2_vpc.id
}

output "arn" {
  value = aws_eks_cluster.m2_eks.arn
}

output "cluster_name" {
  value = aws_eks_cluster.m2_eks.id
}

output "cluster_endpoint" {
  value = aws_eks_cluster.m2_eks.endpoint
}

output "cluster_certificate_authority_data" {
  value = aws_eks_cluster.m2_eks.certificate_authority[0].data
}

output "local_name" {
  value = local.name
}

output "eks_app" {
  value = var.app
}

output "eks_env" {
  value = var.env
}


################################################################################
# SSM
################################################################################

resource "aws_ssm_parameter" "m2_ssm_eks_cluster_name" {
  name  = "/${var.org}/${var.division}/${var.app}/${terraform.workspace}/eks_cluster_name"
  type  = "String"
  value = aws_eks_cluster.m2_eks.id
}

resource "aws_ssm_parameter" "m2_ssm_eks_cluster_region" {
  name  = "/${var.org}/${var.division}/${var.app}/${terraform.workspace}/eks_cluster_region"
  type  = "String"
  value = var.region
}

resource "aws_ssm_parameter" "m2_ssm_vpc_id" {
  name  = "/${var.org}/${var.division}/${var.app}/${terraform.workspace}/eks_vpc_id"
  type  = "String"
  value = aws_vpc.m2_vpc.id
}

resource "aws_ssm_parameter" "m2_ssm_private_subnets" {
  name  = "/${var.org}/${var.division}/${var.app}/${terraform.workspace}/eks_private_subnets"
  type  = "StringList"
  value = "${aws_subnet.m2_private_subnet_1.id},${aws_subnet.m2_private_subnet_2.id}"
}

resource "aws_ssm_parameter" "m2_ssm_public_subnets" {
  name  = "/${var.org}/${var.division}/${var.app}/${terraform.workspace}/eks_public_subnets"
  type  = "StringList"
  value = "${aws_subnet.m2_public_subnet_1.id},${aws_subnet.m2_public_subnet_2.id}"
}