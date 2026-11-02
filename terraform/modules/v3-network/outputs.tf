output "vpc_id" {
  value = aws_vpc.this.id
}
output "public_subnet_ids" {
  value = [aws_subnet.public["a"].id, aws_subnet.public["b"].id]
}
output "private_subnet_ids" {
  value = [aws_subnet.private["a"].id, aws_subnet.private["b"].id]
}
output "database_subnet_ids" {
  value = [aws_subnet.database["a"].id, aws_subnet.database["b"].id]
}
output "nat_gateway_id" {
  value = aws_nat_gateway.this.id
}
