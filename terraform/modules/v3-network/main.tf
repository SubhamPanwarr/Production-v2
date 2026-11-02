# CIDR layout for a /16 VPC:
# Public A/B   = 10.30.1.0/24, 10.30.2.0/24
# Private A/B  = 10.30.11.0/24, 10.30.12.0/24
# Database A/B = 10.30.21.0/24, 10.30.22.0/24
locals {
  public_subnets = {
    a = { az = var.availability_zones[0], cidr = cidrsubnet(var.vpc_cidr, 8, 1) }
    b = { az = var.availability_zones[1], cidr = cidrsubnet(var.vpc_cidr, 8, 2) }
  }
  private_subnets = {
    a = { az = var.availability_zones[0], cidr = cidrsubnet(var.vpc_cidr, 8, 11) }
    b = { az = var.availability_zones[1], cidr = cidrsubnet(var.vpc_cidr, 8, 12) }
  }
  database_subnets = {
    a = { az = var.availability_zones[0], cidr = cidrsubnet(var.vpc_cidr, 8, 21) }
    b = { az = var.availability_zones[1], cidr = cidrsubnet(var.vpc_cidr, 8, 22) }
  }
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                = merge(var.tags, { Name = var.name })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-igw" })
}

resource "aws_subnet" "public" {
  for_each                = local.public_subnets
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name                                      = "${var.name}-public-${each.key}"
    "kubernetes.io/role/elb"                  = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
}

resource "aws_subnet" "private" {
  for_each                = local.private_subnets
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name                                      = "${var.name}-private-${each.key}"
    "kubernetes.io/role/internal-elb"         = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
}

resource "aws_subnet" "database" {
  for_each                = local.database_subnets
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = false

  tags = merge(var.tags, { Name = "${var.name}-database-${each.key}" })
}

# Public ALB subnets: route internet traffic through an IGW.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-public-rt" })
}
resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}
resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# One NAT gateway for this lab: private EKS nodes can pull images from ECR.
# Not multi-AZ resilient: production HA would use one NAT per AZ.
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.name}-nat-eip" })
}
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public["a"].id
  depends_on    = [aws_internet_gateway.this]
  tags          = merge(var.tags, { Name = "${var.name}-nat" })
}
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-private-rt" })
}
resource "aws_route" "private_internet" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this.id
}
resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

# Dedicated database subnets deliberately have NO route to IGW or NAT.
resource "aws_route_table" "database" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-database-rt" })
}
resource "aws_route_table_association" "database" {
  for_each       = aws_subnet.database
  subnet_id      = each.value.id
  route_table_id = aws_route_table.database.id
}
