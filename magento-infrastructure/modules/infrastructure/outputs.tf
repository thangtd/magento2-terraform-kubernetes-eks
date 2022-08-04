output "vpc_id" {
  value = aws_vpc.magento_vpc.id
}

output "arn" {
  value = aws_eks_cluster.magento_eks.arn
}

output "eks_cluster_name" {
  value = aws_eks_cluster.magento_eks.id
}

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.magento_eks.endpoint
}

output "eks_cluster_certificate_authority_data" {
  value = aws_eks_cluster.magento_eks.certificate_authority[0].data
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

output "private_subnet_ids" {
  value = "${aws_subnet.magento_private_subnet_1.id},${aws_subnet.magento_private_subnet_2.id}"
}

output "public_subnet_ids" {
  value = "${aws_subnet.magento_public_subnet_1.id},${aws_subnet.magento_public_subnet_2.id}"
}

################################################################################
# SSM
################################################################################

resource "aws_ssm_parameter" "magento_ssm_eks_cluster_name" {
  name  = "/${var.org}/${var.division}/${var.app}/${var.env}/eks_cluster_name"
  type  = "String"
  value = aws_eks_cluster.magento_eks.id
}

resource "aws_ssm_parameter" "magento_ssm_vpc_id" {
  name  = "/${var.org}/${var.division}/${var.app}/${var.env}/eks_vpc_id"
  type  = "String"
  value = aws_vpc.magento_vpc.id
}

resource "aws_ssm_parameter" "magento_ssm_private_subnets" {
  name  = "/${var.org}/${var.division}/${var.app}/${var.env}/eks_private_subnets"
  type  = "StringList"
  value = "${aws_subnet.magento_private_subnet_1.id},${aws_subnet.magento_private_subnet_2.id}"
}

resource "aws_ssm_parameter" "magento_ssm_public_subnets" {
  name  = "/${var.org}/${var.division}/${var.app}/${var.env}/eks_public_subnets"
  type  = "StringList"
  value = "${aws_subnet.magento_public_subnet_1.id},${aws_subnet.magento_public_subnet_2.id}"
}