# =======================================================
# Bastion
# =======================================================
module "bastion" {
  source = "../../../modules/bastion"

  name          = "prod-bastion"
  ami_id        = var.ami_id
  instance_type = var.instance_type

  subnet_id = module.vpc_a.public_subnet_id
  vpc_id    = module.vpc_a.vpc_id

  key_name   = var.key_name
  admin_cidr = var.admin_cidr

  tags = local.common_tags
}

# =======================================================
# Private EC2 in VPC-A
# =======================================================
module "ec2_a" {
  source = "../../../modules/ec2"

  instance_name = "prod-ec2-a"
  ami_id        = var.ami_id
  instance_type = var.instance_type

  subnet_id = module.vpc_a.private_subnet_id
  vpc_id    = module.vpc_a.vpc_id
  key_name  = var.key_name

  iam_instance_profile = module.ec2_s3_iam.instance_profile_name

  ssh_allowed_cidrs = ["10.10.1.0/24"]

  tags = local.common_tags
}

# =======================================================
# Private EC2 in VPC-B
# =======================================================
module "ec2_b" {
  source = "../../../modules/ec2"

  instance_name = "prod-ec2-b"
  ami_id        = var.ami_id
  instance_type = var.instance_type

  subnet_id = module.vpc_b.private_subnet_id
  vpc_id    = module.vpc_b.vpc_id
  key_name  = var.key_name

  iam_instance_profile = module.ec2_s3_iam.instance_profile_name

  # Bastion is in VPC-A.
  ssh_allowed_cidrs = ["10.10.0.0/16"]

  tags = local.common_tags
}
