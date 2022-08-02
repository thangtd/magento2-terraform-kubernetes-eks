################################################################################
# LOCAL
################################################################################

locals {
  name         = "${var.org}-${var.division}-${var.app}-${var.env}"
  cluster_name = "${local.name}-eks"
  common_tags = merge(
    {
      Org = var.org
      Env = var.env
      Div = var.division
      App = var.app
    },
    var.labels
  )
}

################################################################################
# VPC
################################################################################
data "aws_availability_zones" "az" {
  state = "available"
}

resource "aws_vpc" "magento_vpc" {
  cidr_block       = var.vpc_cidr
  instance_tenancy = "default"

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name}-vpc"
    }
  )

}

resource "aws_subnet" "magento_public_subnet_1" {
  vpc_id     = aws_vpc.magento_vpc.id
  cidr_block = "10.0.0.0/24"

  availability_zone       = data.aws_availability_zones.az.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name                                          = "${local.name}-public-subnet-1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = 1
  }
}

resource "aws_subnet" "magento_public_subnet_2" {
  vpc_id     = aws_vpc.magento_vpc.id
  cidr_block = "10.0.1.0/24"

  availability_zone       = data.aws_availability_zones.az.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name                                          = "${local.name}-public-subnet-2"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = 1
  }
}

resource "aws_subnet" "magento_private_subnet_1" {
  vpc_id     = aws_vpc.magento_vpc.id
  cidr_block = "10.0.2.0/24"

  availability_zone = data.aws_availability_zones.az.names[0]

  tags = {
    Name = "${local.name}-private-subnet-1"
    # AWS Ingress Controller needs these tags to identify the subnet
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = 1
  }
}

resource "aws_subnet" "magento_private_subnet_2" {
  vpc_id     = aws_vpc.magento_vpc.id
  cidr_block = "10.0.3.0/24"

  availability_zone = data.aws_availability_zones.az.names[1]

  tags = {
    Name                                          = "${local.name}-private-subnet-2"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = 1
  }
}

resource "aws_route_table" "magento_public_route_table" {
  vpc_id = aws_vpc.magento_vpc.id

  tags = {
    Name = "${local.name}-public-route-table"
  }
}

resource "aws_route" "magento_public_route" {
  route_table_id         = aws_route_table.magento_public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.magento_igw.id
}


resource "aws_route_table_association" "public_subnet1_to_public_rt" {
  subnet_id      = aws_subnet.magento_public_subnet_1.id
  route_table_id = aws_route_table.magento_public_route_table.id
}

resource "aws_route_table_association" "public_subnet2_to_public_rt" {
  subnet_id      = aws_subnet.magento_public_subnet_2.id
  route_table_id = aws_route_table.magento_public_route_table.id
}

resource "aws_route_table" "magento_private_route_table" {
  vpc_id = aws_vpc.magento_vpc.id

  tags = {
    Name = "${local.name}-private-route-table"
  }
}

resource "aws_route" "magento_private_route" {
  route_table_id         = aws_route_table.magento_private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.magento_nat_gateway.id
}

resource "aws_route_table_association" "private_subnet1_to_private_rt" {
  subnet_id      = aws_subnet.magento_private_subnet_1.id
  route_table_id = aws_route_table.magento_private_route_table.id
}

resource "aws_route_table_association" "private_subnet2_to_private_rt" {
  subnet_id      = aws_subnet.magento_private_subnet_2.id
  route_table_id = aws_route_table.magento_private_route_table.id
}

# Internet Gateway
resource "aws_internet_gateway" "magento_igw" {
  vpc_id = aws_vpc.magento_vpc.id

  tags = {
    Name = "${local.name}-igw"
  }
}


# NAT Gateway
resource "aws_eip" "magento_eip_for_natgw" {
  vpc  = true
  tags = local.common_tags
}

resource "aws_nat_gateway" "magento_nat_gateway" {
  allocation_id = aws_eip.magento_eip_for_natgw.id
  subnet_id     = aws_subnet.magento_public_subnet_1.id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name}-nat-gateway"
    }
  )

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.magento_igw]
}

################################################################################
# EKS Cluster
################################################################################

resource "aws_iam_role" "eks_iam_role" {
  name = "${local.cluster_name}-iam-role"

  assume_role_policy = <<POLICY
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "Service": "eks.amazonaws.com"
          },
          "Action": "sts:AssumeRole"
        }
      ]
    }
    POLICY

}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_iam_role.name
}

resource "aws_eks_cluster" "magento_eks" {
  name     = local.cluster_name
  role_arn = aws_iam_role.eks_iam_role.arn

  version = var.kube_version

  #enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  vpc_config {
    subnet_ids = [aws_subnet.magento_private_subnet_1.id, aws_subnet.magento_private_subnet_2.id]
  }

  tags = local.common_tags

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_vpc.magento_vpc,
    aws_subnet.magento_private_subnet_1,
    aws_subnet.magento_private_subnet_2,
    aws_subnet.magento_public_subnet_1,
    aws_subnet.magento_public_subnet_2,
    aws_route.magento_public_route,
    aws_route.magento_private_route,
    aws_route_table_association.public_subnet1_to_public_rt,
    aws_route_table_association.public_subnet2_to_public_rt,
    aws_route_table_association.private_subnet1_to_private_rt,
    aws_route_table_association.private_subnet2_to_private_rt,
    aws_nat_gateway.magento_nat_gateway,
    aws_iam_role_policy_attachment.eks_cluster_policy_attachment
  ]
}

################################################################################
# EKS Node Group
################################################################################

resource "aws_iam_role" "eks_ng_iam_role" {
  name = "${local.cluster_name}-ng-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "eks-ng-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_ng_iam_role.name
}

resource "aws_iam_role_policy_attachment" "eks-ng-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_ng_iam_role.name
}

resource "aws_iam_role_policy_attachment" "eks-ng-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_ng_iam_role.name
}

resource "aws_eks_node_group" "eks_node_group" {
  cluster_name    = aws_eks_cluster.magento_eks.name
  node_group_name = "${local.cluster_name}-memory-ng"
  node_role_arn   = aws_iam_role.eks_ng_iam_role.arn
  #subnet_ids      = [aws_subnet.magento_private_subnet_1.id, aws_subnet.magento_private_subnet_2.id]

  # TODO: Using public subnets for testing purpose using NodePort
  subnet_ids = [aws_subnet.magento_public_subnet_1.id, aws_subnet.magento_public_subnet_2.id]

  ami_type       = var.amitype
  instance_types = var.instance_types
  capacity_type  = var.capacity_type

  remote_access {
    ec2_ssh_key = var.ng_ssh_key
    #source_security_group_ids = [aws_security_group.magento_bastion_sg.id]
  }

  scaling_config {
    desired_size = var.ng_desired_size
    max_size     = var.ng_max_size
    min_size     = var.ng_min_size
  }

  update_config {
    max_unavailable = 1
  }

  tags = merge(
    local.common_tags,
    {
      # Cluster Autoscaler needs these tags to discover the node group.
      "k8s.io/cluster-autoscaler/enabled"               = true
      "k8s.io/cluster-autoscaler/${local.cluster_name}" = "owned"
    }
  )

  labels = local.common_tags

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.eks-ng-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.eks-ng-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.eks-ng-AmazonEC2ContainerRegistryReadOnly,
    aws_eks_cluster.magento_eks
  ]

}


################################################################################
# EKS Fargate Profile
################################################################################

resource "aws_iam_role" "magento_eks_fargate_role" {
  name = "magento-eks-fargate-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks-fargate-pods.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_policy" "magento_eks_fargate_policy" {
  name        = "magento-eks-fargate-policy"
  path        = "/"
  description = "magento-eks-fargate-policy"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "appmesh:StreamAggregatedResources",
          "appmesh:*",
          "xray:*"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "acm:ExportCertificate",
          "acm-pca:GetCertificateAuthorityCertificate"
        ],
        "Resource" : "*"
      },
      {
        "Action" : [
          "logs:*"
        ],
        "Effect" : "Allow",
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "magento_fargate_role_policy_attachment" {
  policy_arn = aws_iam_policy.magento_eks_fargate_policy.arn
  role       = aws_iam_role.magento_eks_fargate_role.name
}

resource "aws_eks_fargate_profile" "magento_fargate_profile" {

  cluster_name           = aws_eks_cluster.magento_eks.name
  fargate_profile_name   = "${local.cluster_name}-fargate-profile"
  pod_execution_role_arn = aws_iam_role.magento_eks_fargate_role.arn

  subnet_ids = [aws_subnet.magento_private_subnet_1.id, aws_subnet.magento_private_subnet_2.id]

  selector {
    namespace = "prodcatalog-ns"
    labels = {
      component = "fargate"
      tier      = "worker"
      app       = "prodcatalog"
    }
  }


  selector {
    namespace = "fargate-ns"
    labels = {
      place = "fargate"
      tier  = "worker"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.magento_fargate_role_policy_attachment,
    aws_eks_cluster.magento_eks
  ]

}
