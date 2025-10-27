# IAM Roles Module
# Creates IAM roles for ECS task execution and task roles

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ECS Task Execution Role
# Used by ECS to pull images from ECR and write logs to CloudWatch
resource "aws_iam_role" "ecs_execution" {
  name_prefix = "${var.project_name}-ecs-exec-${var.region_name}-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-ecs-execution-role-${var.region_name}"
    }
  )
}

# Attach AWS managed policy for ECS task execution
resource "aws_iam_role_policy_attachment" "ecs_execution_policy" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Additional policy for Secrets Manager access
resource "aws_iam_role_policy" "ecs_execution_secrets" {
  name_prefix = "${var.project_name}-ecs-exec-secrets-"
  role        = aws_iam_role.ecs_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:*:${var.aws_account_id}:secret:hyundai-poc/*"
      }
    ]
  })
}

# ECS Task Role
# Used by the application code running in ECS tasks
resource "aws_iam_role" "ecs_task" {
  name_prefix = "${var.project_name}-ecs-task-${var.region_name}-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-ecs-task-role-${var.region_name}"
    }
  )
}

# Policy for ECS tasks to publish custom metrics to CloudWatch
resource "aws_iam_role_policy" "ecs_task_cloudwatch" {
  name_prefix = "${var.project_name}-ecs-task-cw-"
  role        = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricStatistics"
        ]
        Resource = "*"
      }
    ]
  })
}

# Policy for ECS tasks to describe RDS clusters (for replication lag metrics)
resource "aws_iam_role_policy" "ecs_task_rds" {
  name_prefix = "${var.project_name}-ecs-task-rds-"
  role        = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds:DescribeDBClusters",
          "rds:DescribeGlobalClusters"
        ]
        Resource = "*"
      }
    ]
  })
}

# Kinesis Firehose Role (for CloudWatch metric streaming)
resource "aws_iam_role" "firehose" {
  name_prefix = "${var.project_name}-firehose-${var.region_name}-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "firehose.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-firehose-role-${var.region_name}"
    }
  )
}

# Policy for Firehose to write to CloudWatch Logs
resource "aws_iam_role_policy" "firehose_cloudwatch" {
  name_prefix = "${var.project_name}-firehose-cw-"
  role        = aws_iam_role.firehose.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:${var.aws_account_id}:log-group:/aws/kinesisfirehose/*"
      }
    ]
  })
}
