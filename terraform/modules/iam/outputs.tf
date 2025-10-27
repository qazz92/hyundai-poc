# IAM Module Outputs

output "ecs_execution_role_arn" {
  description = "ARN of ECS task execution role"
  value       = aws_iam_role.ecs_execution.arn
}

output "ecs_task_role_arn" {
  description = "ARN of ECS task role"
  value       = aws_iam_role.ecs_task.arn
}

output "firehose_role_arn" {
  description = "ARN of Kinesis Firehose role"
  value       = aws_iam_role.firehose.arn
}
