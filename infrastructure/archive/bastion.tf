
# ##############################################################################
# Bastion Node
# ##############################################################################

resource "aws_security_group" "m2_bastion_sg" {

  name        = "${local.name}-bastion-sg"
  description = "Allow SSH to Bastion Node"
  vpc_id      = aws_vpc.m2_vpc.id

  ingress {
    description = "Allow SSH to Bastion Node"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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
      Name = "${local.name}-bastion-sg"
    }
  )

}

resource "aws_instance" "m2_basion" {

  ami                    = var.bastion_ami
  instance_type          = "t3.micro"
  key_name               = var.bastion_ssh_key
  subnet_id              = aws_subnet.m2_public_subnet_1.id
  vpc_security_group_ids = [aws_security_group.m2_bastion_sg.id]

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name}-bastion"
    }
  )

  depends_on = [aws_internet_gateway.m2_igw]

}

resource "aws_eip" "m2_bastion_eip" {
  instance = aws_instance.m2_basion.id
  vpc      = true
}


resource "null_resource" "copy_private_key" {

  depends_on = [aws_eip.m2_bastion_eip]

  connection {
    type        = "ssh"
    user        = "ec2-user"
    host        = aws_eip.m2_bastion_eip.public_ip
    password    = ""
    private_key = file("data/terraform.pem")
    agent       = false
  }

  provisioner "remote-exec" {
    inline = [
      "sudo rm -rf /tmp/terraform.pem"
    ]
  }

  provisioner "file" {
    source      = "data/terraform.pem"
    destination = "/tmp/terraform.pem"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod 400 /tmp/terraform.pem",
      "echo \"Hiii Terraform\" >> /tmp/hi_terraform.txt",
      "cat /tmp/hi_terraform.txt"
    ]
  }


  # provisioner "local-exec" {
  #   command = "echo VPC created on `date` - VPC ID: ${module.vpc.vpc_id}"
  #   working_dir = "data"
  # }


}