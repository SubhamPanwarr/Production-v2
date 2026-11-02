output "rds_endpoint" {
  value = module.rds.endpoint
}

output "rds_port" {
  value = module.rds.port
}

output "rds_instance_id" {
  value = module.rds.db_instance_id
}

output "rds_security_group_id" {
  value = module.rds.security_group_id
}

output "rds_master_secret_arn" {
  value     = module.rds.master_user_secret_arn
  sensitive = true
}
