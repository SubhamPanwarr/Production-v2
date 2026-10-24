resource "aws_ec2_transit_gateway" "this" {
  description = var.description

  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  dns_support                     = "enable"

  tags = merge(
    var.tags,
    {
      Name = var.name
    }
  )
}

resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  for_each = var.vpc_attachments

  subnet_ids         = each.value.subnet_ids
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  vpc_id             = each.value.vpc_id

  dns_support = "enable"

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-${each.key}-attachment"
    }
  )
}
