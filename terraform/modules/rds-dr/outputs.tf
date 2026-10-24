output "cross_region_replica_endpoint" {
  value = (
    var.create_cross_region_replica
    ? aws_db_instance.cross_region_replica[0].address
    : null
  )
}

output "cross_region_replica_arn" {
  value = (
    var.create_cross_region_replica
    ? aws_db_instance.cross_region_replica[0].arn
    : null
  )
}

output "dr_kms_key_arn" {
  value = aws_kms_key.rds_dr.arn
}

output "automated_backup_replication_id" {
  value = (
    var.enable_cross_region_backups
    ? aws_db_instance_automated_backups_replication.dr[0].id
    : null
  )
}

output "cross_region_snapshot_arn" {
  value = (
    var.create_cross_region_snapshot &&
    var.source_snapshot_arn != null
    ? aws_db_snapshot_copy.cross_region[0].db_snapshot_arn
    : null
  )
}
