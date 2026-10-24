output "endpoint" {
  description = "Primary RDS endpoint"
  value       = aws_db_instance.this.address
}

output "port" {
  description = "Primary RDS port"
  value       = aws_db_instance.this.port
}

output "db_instance_id" {
  description = "Primary DB instance ID"
  value       = aws_db_instance.this.id
}

output "db_instance_arn" {
  description = "Primary RDS ARN"
  value       = aws_db_instance.this.arn
}

output "security_group_id" {
  description = "RDS security group ID"
  value       = aws_security_group.rds.id
}

output "subnet_group_name" {
  description = "RDS DB subnet group name"
  value       = aws_db_subnet_group.this.name
}

output "parameter_group_name" {
  description = "Custom RDS parameter group name"
  value       = var.create_parameter_group ? aws_db_parameter_group.this[0].name : null
}

output "read_replica_endpoint" {
  description = "Same-region read replica endpoint"
  value = (
    var.create_read_replica
    ? aws_db_instance.read_replica[0].address
    : null
  )
}

output "read_replica_arn" {
  description = "Same-region read replica ARN"
  value = (
    var.create_read_replica
    ? aws_db_instance.read_replica[0].arn
    : null
  )
}

output "master_user_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the RDS master credentials"
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
  sensitive   = true
}
