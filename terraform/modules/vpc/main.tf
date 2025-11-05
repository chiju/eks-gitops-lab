# VPC - isolated network
resource "aws_vpc" "vpc_lrn" {
  cidr_block = var.cidr
  enable_dns_hostnames = true
  enable_dns_support = true

  tags = {
    Name = "${var.cluster_name}-vpc_lrn"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw_lrn" {
  vpc_id = aws_vpc.vpc_lrn.id
  tags = {
    Name = "${var.cluster_name}-igw_lrn"
  }
}

# Public Subnets
resource "aws_subnet" "subnet_public_lrn" {
  count = length(var.availability_zones)
  vpc_id = aws_vpc.vpc_lrn.id
  cidr_block = cidrsubnet(var.cidr, 4, count.index)
  availability_zone = var.availability_zones[count.index]
  map_public_ip_on_launch = false
  tags = {
    Name = "${var.cluster_name}-subnet_public_lrn-${var.availability_zones[count.index]}"
    "kubernetes.io/role/elb" = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# Private Subnets
resource "aws_subnet" "subnet_private_lrn" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.vpc_lrn.id
  cidr_block        = cidrsubnet(var.cidr, 4, count.index + length(var.availability_zones))
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name                                        = "${var.cluster_name}-subnet_private_lrn-${var.availability_zones[count.index]}"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "eip_nat_lrn" {
  domain = "vpc"
  tags = {
    Name = "${var.cluster_name}-eip_nat_lrn"
  }
  depends_on = [ aws_internet_gateway.igw_lrn ]
}

# NAT Gateway
resource "aws_nat_gateway" "natgw_lrn" {
  allocation_id = aws_eip.eip_nat_lrn.id
  subnet_id = aws_subnet.subnet_public_lrn[0].id
  tags = {
    Name = "${var.cluster_name}-natgw_lrn"
  }
  depends_on = [ aws_internet_gateway.igw_lrn ]
}

# Public Route Table
resource "aws_route_table" "rt_public_lrn" {
  vpc_id = aws_vpc.vpc_lrn.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_lrn.id
  }
  tags = {
    Name = "${var.cluster_name}-rt_public_lrn"
  }
}

# Private Route Table (single, shared by both private subnets)
resource "aws_route_table" "rt_private_lrn" {
  vpc_id = aws_vpc.vpc_lrn.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natgw_lrn.id
  }
  tags = {
    Name = "${var.cluster_name}-rt_private_lrn"
  }
}

# Associate public subnets with public route table
resource "aws_route_table_association" "rta_public_lrn" {
  count = length(var.availability_zones)
  subnet_id = aws_subnet.subnet_public_lrn[count.index].id
  route_table_id = aws_route_table.rt_public_lrn.id
}

# Associate private subnets with private route table
resource "aws_route_table_association" "rta_private_lrn" {
  count = length(var.availability_zones)
  subnet_id = aws_subnet.subnet_private_lrn[count.index].id
  route_table_id = aws_route_table.rt_private_lrn.id
}
