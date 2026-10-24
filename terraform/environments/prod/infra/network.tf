# =======================================================
# VPC-A - Primary application VPC
# =======================================================
module "vpc_a" {
  source = "../../../modules/vpc"

  vpc_name = "prod-vpc-a"
  vpc_cidr = "10.10.0.0/16"

  public_subnet_cidr  = "10.10.1.0/24"
  private_subnet_cidr = "10.10.2.0/24"
  tgw_subnet_cidr     = "10.10.10.0/28"

  availability_zone = var.availability_zone
  create_igw        = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = local.common_tags
}

# =======================================================
# VPC-B - Secondary private VPC
# =======================================================
module "vpc_b" {
  source = "../../../modules/vpc"

  vpc_name = "prod-vpc-b"
  vpc_cidr = "10.20.0.0/16"

  private_subnet_cidr = "10.20.2.0/24"
  tgw_subnet_cidr     = "10.20.10.0/28"

  availability_zone = var.availability_zone
  create_igw        = false

  tags = local.common_tags
}

# =======================================================
# Second AZ subnets in VPC-A
# =======================================================
resource "aws_subnet" "vpc_a_public_2" {
  vpc_id                  = module.vpc_a.vpc_id
  cidr_block              = "10.10.3.0/24"
  availability_zone       = var.availability_zone_2
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name                     = "prod-vpc-a-public-subnet-2"
    "kubernetes.io/role/elb" = "1"
  })
}

resource "aws_route_table_association" "vpc_a_public_2" {
  subnet_id      = aws_subnet.vpc_a_public_2.id
  route_table_id = module.vpc_a.public_route_table_id
}

resource "aws_subnet" "vpc_a_private_2" {
  vpc_id                  = module.vpc_a.vpc_id
  cidr_block              = "10.10.4.0/24"
  availability_zone       = var.availability_zone_2
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name                              = "prod-vpc-a-private-subnet-2"
    "kubernetes.io/role/internal-elb" = "1"
  })
}

resource "aws_route_table_association" "vpc_a_private_2" {
  subnet_id      = aws_subnet.vpc_a_private_2.id
  route_table_id = module.vpc_a.private_route_table_id
}

# =======================================================
# NAT Gateway for private workloads
# =======================================================
resource "aws_eip" "nat_vpc_a" {
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "prod-vpc-a-nat-eip"
  })
}

resource "aws_nat_gateway" "vpc_a" {
  allocation_id = aws_eip.nat_vpc_a.id
  subnet_id     = module.vpc_a.public_subnet_id

  tags = merge(local.common_tags, {
    Name = "prod-vpc-a-nat"
  })

  depends_on = [module.vpc_a]
}

resource "aws_route" "vpc_a_private_internet" {
  route_table_id         = module.vpc_a.private_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.vpc_a.id
}

# =======================================================
# Transit Gateway
# =======================================================
module "transit_gateway" {
  source = "../../../modules/transit-gateway"

  name        = "prod-tgw"
  description = "Production Transit Gateway"

  vpc_attachments = {
    vpc-a = {
      vpc_id     = module.vpc_a.vpc_id
      subnet_ids = [module.vpc_a.tgw_subnet_id]
    }

    vpc-b = {
      vpc_id     = module.vpc_b.vpc_id
      subnet_ids = [module.vpc_b.tgw_subnet_id]
    }
  }

  tags = local.common_tags
}

resource "aws_route" "vpc_a_private_to_vpc_b" {
  route_table_id         = module.vpc_a.private_route_table_id
  destination_cidr_block = "10.20.0.0/16"
  transit_gateway_id     = module.transit_gateway.transit_gateway_id
}

resource "aws_route" "vpc_a_public_to_vpc_b" {
  route_table_id         = module.vpc_a.public_route_table_id
  destination_cidr_block = "10.20.0.0/16"
  transit_gateway_id     = module.transit_gateway.transit_gateway_id
}

resource "aws_route" "vpc_b_private_to_vpc_a" {
  route_table_id         = module.vpc_b.private_route_table_id
  destination_cidr_block = "10.10.0.0/16"
  transit_gateway_id     = module.transit_gateway.transit_gateway_id
}

# =======================================================
# S3 Gateway Endpoints
# =======================================================
module "s3_endpoint_vpc_a" {
  source = "../../../modules/vpc-endpoint"

  vpc_id     = module.vpc_a.vpc_id
  aws_region = var.aws_region

  route_table_ids = [module.vpc_a.private_route_table_id]
  endpoint_name   = "prod-vpc-a-s3-endpoint"

  tags = local.common_tags
}

module "s3_endpoint_vpc_b" {
  source = "../../../modules/vpc-endpoint"

  vpc_id     = module.vpc_b.vpc_id
  aws_region = var.aws_region

  route_table_ids = [module.vpc_b.private_route_table_id]
  endpoint_name   = "prod-vpc-b-s3-endpoint"

  tags = local.common_tags
}
