# Monitoring Module Outputs

output "dashboard_name" {
  description = "CloudWatch dashboard name"
  value       = aws_cloudwatch_dashboard.main_new.dashboard_name
}

output "dashboard_arn" {
  description = "CloudWatch dashboard ARN"
  value       = aws_cloudwatch_dashboard.main_new.dashboard_arn
}

output "firehose_delivery_stream_arn" {
  description = "Kinesis Firehose delivery stream ARN"
  value       = var.create_firehose ? aws_kinesis_firehose_delivery_stream.metrics[0].arn : ""
}

output "firehose_delivery_stream_name" {
  description = "Kinesis Firehose delivery stream name"
  value       = var.create_firehose ? aws_kinesis_firehose_delivery_stream.metrics[0].name : ""
}

output "metric_stream_arn" {
  description = "CloudWatch metric stream ARN"
  value       = var.create_firehose ? aws_cloudwatch_metric_stream.main[0].arn : ""
}

output "metric_stream_name" {
  description = "CloudWatch metric stream name"
  value       = var.create_firehose ? aws_cloudwatch_metric_stream.main[0].name : ""
}

output "metrics_bucket_name" {
  description = "S3 bucket name for metrics storage"
  value       = var.create_firehose ? aws_s3_bucket.metrics[0].id : ""
}

output "metrics_log_group_name" {
  description = "CloudWatch log group name for Firehose"
  value       = var.create_firehose ? aws_cloudwatch_log_group.firehose[0].name : ""
}
