
################################################################################
# RDS MYSQL DB
################################################################################

resource "aws_ssm_parameter" "m2_rds_db_username" {
  name  = "/${var.org}/${var.division}/${var.app}/${terraform.workspace}/rds_db_username"
  type  = "SecureString"
  value = "securedme"
}

resource "aws_ssm_parameter" "m2_rds_db_password" {
  name  = "/${var.org}/${var.division}/${var.app}/${terraform.workspace}/rds_db_password"
  type  = "SecureString"
  value = "securedmepass"
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "${local.name}-rds-subnet-group"
  subnet_ids = [aws_subnet.m2_private_subnet_1.id, aws_subnet.m2_private_subnet_2.id]

  tags = local.common_tags
}


resource "aws_security_group" "rds_db_sg" {

  name        = "${local.name}-rds-db-sg"
  description = "Allow Worker Nodes access to RDS DB"
  vpc_id      = aws_vpc.m2_vpc.id

  ingress {
    description     = "Allow Worker Nodes access to RDS DB"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_eks_cluster.m2_eks.vpc_config[0].cluster_security_group_id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name}-rds-db-sg"
    }
  )

}

resource "aws_db_instance" "rds_mysql_magento2" {
  allocated_storage      = 20
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  db_name                = "magento2db"
  username               = aws_ssm_parameter.m2_rds_db_username.value
  password               = aws_ssm_parameter.m2_rds_db_password.value
  parameter_group_name   = "default.mysql8.0"
  skip_final_snapshot    = true
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_db_sg.id]
  tags                   = local.common_tags
}

output "rds_address" {
  value = aws_db_instance.rds_mysql_magento2.address
}

resource "aws_ssm_parameter" "m2_rds_address" {
  name  = "/${var.org}/${var.division}/${var.app}/${terraform.workspace}/m2_rds_address"
  type  = "StringList"
  value = aws_db_instance.rds_mysql_magento2.address
}