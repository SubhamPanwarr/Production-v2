resource "aws_security_group" "bastion" {
  name        = "${var.name}-sg"
  description = "Bastion security group"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH from administrator"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-sg"
    }
  )
}

resource "aws_instance" "bastion" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  key_name                    = var.key_name
  associate_public_ip_address = true

  vpc_security_group_ids = [
    aws_security_group.bastion.id
  ]

  root_block_device {
    volume_type = "gp3"
    volume_size = 10
    encrypted   = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = merge(
    var.tags,
    {
      Name = var.name
    }
  )
}

resource "aws_eip" "bastion" {
  domain = "vpc"

  instance = aws_instance.bastion.id

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-eip"
    }
  )
}
