output "vpc_id" {
  value = aws_vpc.this.id
}

output "vpc_cidr" {
  value = aws_vpc.this.cidr_block
}

output "public_subnet_id" {
  value = try(aws_subnet.public[0].id, null)
}

output "private_subnet_id" {
  value = aws_subnet.private.id
}

output "tgw_subnet_id" {
  value = aws_subnet.tgw.id
}

output "public_route_table_id" {
  value = try(aws_route_table.public[0].id, null)
}

output "private_route_table_id" {
  value = aws_route_table.private.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"

  value = aws_subnet.private[*].id
}

