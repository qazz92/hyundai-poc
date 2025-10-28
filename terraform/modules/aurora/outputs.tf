# Aurora Module Outputs

output "global_cluster_id" {
  description = "Global Cluster ID"
  value       = var.is_primary && length(aws_rds_global_cluster.main) > 0 ? aws_rds_global_cluster.main[0].id : null
}

output "cluster_id" {
  description = "Aurora cluster identifier"
  value       = aws_rds_cluster.aurora.cluster_identifier
}

output "cluster_arn" {
  description = "Aurora cluster ARN"
  value       = aws_rds_cluster.aurora.arn
}

output "writer_endpoint" {
  description = "Aurora cluster writer endpoint"
  value       = aws_rds_cluster.aurora.endpoint
}

output "reader_endpoint" {
  description = "Aurora cluster reader endpoint"
  value       = aws_rds_cluster.aurora.reader_endpoint
}

output "cluster_members" {
  description = "List of cluster instance identifiers"
  value       = aws_rds_cluster.aurora.cluster_members
}

output "database_name" {
  description = "Database name"
  value       = aws_rds_cluster.aurora.database_name
}

output "port" {
  description = "Database port"
  value       = aws_rds_cluster.aurora.port
}
