# ==============================================================================
# NETWORK MODULE
# VPC, 6 subnets (2 public / 2 private-app / 2 private-data) across 2 AZs,
# Internet Gateway, NAT Gateway, and route tables.
# ==============================================================================

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  az_a = data.aws_availability_zones.available.names[0]
  az_b = data.aws_availability_zones.available.names[1]

  # EKS auto-discovers subnets by these tags when creating ALBs/NLBs via the
  # AWS Load Balancer Controller. Only applied when eks_cluster_name is set.
  eks_public_tags = var.eks_cluster_name == "" ? {} : {
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
    "kubernetes.io/role/elb"                         = "1"
  }

  eks_private_tags = var.eks_cluster_name == "" ? {} : {
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"                = "1"
  }
}

# --- VPC ---
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-vpc"
  })
}

# --- Public subnets (ALB, bastion host) ---
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block               = var.public_subnet_cidrs[0]
  availability_zone        = local.az_a
  map_public_ip_on_launch  = true

  tags = merge(var.common_tags, local.eks_public_tags, { Name = "${var.name_prefix}-public-1" })
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block               = var.public_subnet_cidrs[1]
  availability_zone        = local.az_b
  map_public_ip_on_launch  = true

  tags = merge(var.common_tags, local.eks_public_tags, { Name = "${var.name_prefix}-public-2" })
}

# --- Private application subnets (ASG EC2 instances) ---
resource "aws_subnet" "private_app_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_app_subnet_cidrs[0]
  availability_zone = local.az_a

  tags = merge(var.common_tags, local.eks_private_tags, { Name = "${var.name_prefix}-private-app-1" })
}

resource "aws_subnet" "private_app_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_app_subnet_cidrs[1]
  availability_zone = local.az_b

  tags = merge(var.common_tags, local.eks_private_tags, { Name = "${var.name_prefix}-private-app-2" })
}

# --- Private data subnets (RDS) ---
resource "aws_subnet" "private_data_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_data_subnet_cidrs[0]
  availability_zone = local.az_a

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-private-data-1" })
}

resource "aws_subnet" "private_data_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_data_subnet_cidrs[1]
  availability_zone = local.az_b

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-private-data-2" })
}

# --- Internet Gateway + NAT Gateway ---
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-igw" })
}

resource "aws_eip" "nat" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-nat-eip" })
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1.id

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-nat-gw" })
}

# --- Public route table ---
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-public-route-table" })
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# --- Private route table ---
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-private-route-table" })
}

resource "aws_route_table_association" "private_app_a" {
  subnet_id      = aws_subnet.private_app_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_app_b" {
  subnet_id      = aws_subnet.private_app_2.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_data_a" {
  subnet_id      = aws_subnet.private_data_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_data_b" {
  subnet_id      = aws_subnet.private_data_2.id
  route_table_id = aws_route_table.private.id
}
