resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    var.tags,
    {
      Name = var.vpc_name
    }
  )
}

# --------------------------------------------------
# Internet Gateway
# Only required where create_igw = true
# --------------------------------------------------

resource "aws_internet_gateway" "this" {
  count = var.create_igw ? 1 : 0

  vpc_id = aws_vpc.this.id

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-igw"
    }
  )
}

# --------------------------------------------------
# Public subnet
# --------------------------------------------------

resource "aws_subnet" "public" {
  count = var.public_subnet_cidr != null ? 1 : 0

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    var.public_subnet_tags,
    {
      Name = "${var.vpc_name}-public-subnet-2"
    }
  )
}

# --------------------------------------------------
# Private subnet
# --------------------------------------------------

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = var.availability_zone

  tags = merge(
    var.tags,
    var.private_subnet_tags,
    {
      Name = "${var.vpc_name}-private-subnet"
    }
  )
}

# --------------------------------------------------
# Dedicated TGW subnet
# --------------------------------------------------

resource "aws_subnet" "tgw" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.tgw_subnet_cidr
  availability_zone = var.availability_zone

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-tgw-subnet"
    }
  )
}

# --------------------------------------------------
# Public route table
# --------------------------------------------------

resource "aws_route_table" "public" {
  count = var.public_subnet_cidr != null ? 1 : 0

  vpc_id = aws_vpc.this.id

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-public-rt"
    }
  )
}

resource "aws_route" "internet" {
  count = var.create_igw && var.public_subnet_cidr != null ? 1 : 0

  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id
}

resource "aws_route_table_association" "public" {
  count = var.public_subnet_cidr != null ? 1 : 0

  subnet_id      = aws_subnet.public[0].id
  route_table_id = aws_route_table.public[0].id
}

# --------------------------------------------------
# Private route table
# --------------------------------------------------

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-private-rt"
    }
  )
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# --------------------------------------------------
# TGW subnet route table
# --------------------------------------------------

resource "aws_route_table" "tgw" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-tgw-rt"
    }
  )
}

resource "aws_route_table_association" "tgw" {
  subnet_id      = aws_subnet.tgw.id
  route_table_id = aws_route_table.tgw.id
}
