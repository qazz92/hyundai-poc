# Monitoring Module - CloudWatch Dashboard and Kinesis Data Firehose
# Creates unified monitoring dashboard and metric streaming

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# CloudWatch Log Group for Kinesis Firehose
resource "aws_cloudwatch_log_group" "firehose" {
  count             = var.create_firehose ? 1 : 0
  name              = "/aws/kinesisfirehose/${var.project_name}-metrics"
  retention_in_days = 7

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-firehose-logs"
    }
  )
}

resource "aws_cloudwatch_log_stream" "firehose" {
  count          = var.create_firehose ? 1 : 0
  name           = "metrics-stream"
  log_group_name = aws_cloudwatch_log_group.firehose[0].name
}

# IAM Role for Kinesis Firehose
resource "aws_iam_role" "firehose" {
  count = var.create_firehose ? 1 : 0
  name  = "${var.project_name}-firehose-role"

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

  tags = var.tags
}

# IAM Policy for Firehose to write to CloudWatch Logs
resource "aws_iam_role_policy" "firehose_cloudwatch" {
  count = var.create_firehose ? 1 : 0
  name  = "${var.project_name}-firehose-cloudwatch-policy"
  role  = aws_iam_role.firehose[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:PutLogEvents",
          "logs:CreateLogStream"
        ]
        Resource = "${aws_cloudwatch_log_group.firehose[0].arn}:*"
      }
    ]
  })
}

# IAM Role for CloudWatch Metric Stream
resource "aws_iam_role" "metric_stream" {
  count = var.create_firehose ? 1 : 0
  name  = "${var.project_name}-metric-stream-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "streams.metrics.cloudwatch.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM Policy for Metric Stream to write to Firehose
resource "aws_iam_role_policy" "metric_stream_firehose" {
  count = var.create_firehose ? 1 : 0
  name  = "${var.project_name}-metric-stream-policy"
  role  = aws_iam_role.metric_stream[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "firehose:PutRecord",
          "firehose:PutRecordBatch"
        ]
        Resource = aws_kinesis_firehose_delivery_stream.metrics[0].arn
      }
    ]
  })
}

# Kinesis Data Firehose Delivery Stream
resource "aws_kinesis_firehose_delivery_stream" "metrics" {
  count       = var.create_firehose ? 1 : 0
  name        = "${var.project_name}-metrics-stream"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn            = aws_iam_role.firehose[0].arn
    bucket_arn          = aws_s3_bucket.metrics[0].arn
    buffering_size      = var.firehose_buffer_size
    buffering_interval  = var.firehose_buffer_interval
    compression_format  = var.firehose_compression
    prefix              = "metrics/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
    error_output_prefix = "errors/!{firehose:error-output-type}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.firehose[0].name
      log_stream_name = aws_cloudwatch_log_stream.firehose[0].name
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-metrics-firehose"
    }
  )
}

# S3 Bucket for Metrics Storage
resource "aws_s3_bucket" "metrics" {
  count  = var.create_firehose ? 1 : 0
  bucket = "${var.project_name}-metrics-${data.aws_caller_identity.current.account_id}"

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-metrics-bucket"
    }
  )
}

# S3 Bucket Lifecycle Policy (delete after 7 days)
resource "aws_s3_bucket_lifecycle_configuration" "metrics" {
  count  = var.create_firehose ? 1 : 0
  bucket = aws_s3_bucket.metrics[0].id

  rule {
    id     = "delete-old-metrics"
    status = "Enabled"

    filter {
      prefix = ""  # Apply to all objects
    }

    expiration {
      days = 7
    }
  }
}

# S3 Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "metrics" {
  count  = var.create_firehose ? 1 : 0
  bucket = aws_s3_bucket.metrics[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CloudWatch Metric Stream
resource "aws_cloudwatch_metric_stream" "main" {
  count         = var.create_firehose ? 1 : 0
  name          = "${var.project_name}-metric-stream"
  role_arn      = aws_iam_role.metric_stream[0].arn
  firehose_arn  = aws_kinesis_firehose_delivery_stream.metrics[0].arn
  output_format = "json"

  # Include specific namespaces
  include_filter {
    namespace = "AWS/ECS"
  }

  include_filter {
    namespace = "AWS/ApplicationELB"
  }

  include_filter {
    namespace = "AWS/RDS"
  }

  include_filter {
    namespace = "HyundaiPOC/Application"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-metric-stream"
    }
  )
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# CloudWatch Dashboard - OLD (Replaced by dashboard.tf)
# # resource "aws_cloudwatch_dashboard" "main" {
# #   dashboard_name = "Hyundai-POC-Global"
# 
#   dashboard_body = jsonencode({
#     widgets = [
#       # Row 1: Regional Health Status
#       {
#         type = "metric"
#         properties = {
#           title   = "Seoul Region - Healthy Hosts"
#           region  = "ap-northeast-2"
#           metrics = [
#             ["AWS/ApplicationELB", "HealthyHostCount", { stat = "Average" }]
#           ]
#           period = 60
#           stat   = "Average"
#           yAxis = {
#             left = {
#               min = 0
#             }
#           }
#         }
#         width  = 8
#         height = 6
#         x      = 0
#         y      = 0
#       },
#       {
#         type = "metric"
#         properties = {
#           title   = "US-East Region - Healthy Hosts"
#           region  = "us-east-1"
#           metrics = [
#             ["AWS/ApplicationELB", "HealthyHostCount", { stat = "Average" }]
#           ]
#           period = 60
#           stat   = "Average"
#           yAxis = {
#             left = {
#               min = 0
#             }
#           }
#         }
#         width  = 8
#         height = 6
#         x      = 8
#         y      = 0
#       },
#       {
#         type = "metric"
#         properties = {
#           title   = "US-West Region - Healthy Hosts"
#           region  = "us-west-2"
#           metrics = [
#             ["AWS/ApplicationELB", "HealthyHostCount", { stat = "Average" }]
#           ]
#           period = 60
#           stat   = "Average"
#           yAxis = {
#             left = {
#               min = 0
#             }
#           }
#         }
#         width  = 8
#         height = 6
#         x      = 16
#         y      = 0
#       },
# 
#       # Row 2: ECS CPU and Memory
#       {
#         type = "metric"
#         properties = {
#           title   = "ECS CPU Utilization - All Regions"
#           region  = "us-east-1"
#           metrics = [
#             ["AWS/ECS", "CPUUtilization", { region = "ap-northeast-2", stat = "Average", label = "Seoul" }],
#             ["AWS/ECS", "CPUUtilization", { region = "us-east-1", stat = "Average", label = "US-East" }],
#             ["AWS/ECS", "CPUUtilization", { region = "us-west-2", stat = "Average", label = "US-West" }]
#           ]
#           period = 60
#           stat   = "Average"
#           yAxis = {
#             left = {
#               min = 0
#               max = 100
#             }
#           }
#         }
#         width  = 12
#         height = 6
#         x      = 0
#         y      = 6
#       },
#       {
#         type = "metric"
#         properties = {
#           title   = "ECS Memory Utilization - All Regions"
#           region  = "us-east-1"
#           metrics = [
#             ["AWS/ECS", "MemoryUtilization", { region = "ap-northeast-2", stat = "Average", label = "Seoul" }],
#             ["AWS/ECS", "MemoryUtilization", { region = "us-east-1", stat = "Average", label = "US-East" }],
#             ["AWS/ECS", "MemoryUtilization", { region = "us-west-2", stat = "Average", label = "US-West" }]
#           ]
#           period = 60
#           stat   = "Average"
#           yAxis = {
#             left = {
#               min = 0
#               max = 100
#             }
#           }
#         }
#         width  = 12
#         height = 6
#         x      = 12
#         y      = 6
#       },
# 
#       # Row 3: ALB Metrics
#       {
#         type = "metric"
#         properties = {
#           title   = "ALB Request Count - All Regions"
#           region  = "us-east-1"
#           view    = "timeSeries"
#           stacked = true
#           metrics = [
#             ["AWS/ApplicationELB", "RequestCount", { region = "ap-northeast-2", stat = "Sum", label = "Seoul" }],
#             ["AWS/ApplicationELB", "RequestCount", { region = "us-east-1", stat = "Sum", label = "US-East" }],
#             ["AWS/ApplicationELB", "RequestCount", { region = "us-west-2", stat = "Sum", label = "US-West" }]
#           ]
#           period = 60
#           stat   = "Sum"
#           yAxis = {
#             left = {
#               min = 0
#             }
#           }
#         }
#         width  = 12
#         height = 6
#         x      = 0
#         y      = 12
#       },
#       {
#         type = "metric"
#         properties = {
#           title   = "ALB Target Response Time - All Regions"
#           region  = "us-east-1"
#           metrics = [
#             ["AWS/ApplicationELB", "TargetResponseTime", { region = "ap-northeast-2", stat = "Average", label = "Seoul" }],
#             ["AWS/ApplicationELB", "TargetResponseTime", { region = "us-east-1", stat = "Average", label = "US-East" }],
#             ["AWS/ApplicationELB", "TargetResponseTime", { region = "us-west-2", stat = "Average", label = "US-West" }]
#           ]
#           period = 60
#           stat   = "Average"
#           yAxis = {
#             left = {
#               min = 0
#             }
#           }
#         }
#         width  = 12
#         height = 6
#         x      = 12
#         y      = 12
#       },
# 
#       # Row 4: Aurora Metrics
#       {
#         type = "metric"
#         properties = {
#           title   = "Aurora CPU Utilization - All Clusters"
#           region  = "us-east-1"
#           metrics = [
#             ["AWS/RDS", "CPUUtilization", { region = "us-east-1", stat = "Average", label = "Primary (US-East)" }],
#             ["AWS/RDS", "CPUUtilization", { region = "ap-northeast-2", stat = "Average", label = "Seoul" }],
#             ["AWS/RDS", "CPUUtilization", { region = "us-west-2", stat = "Average", label = "US-West" }]
#           ]
#           period = 60
#           stat   = "Average"
#           yAxis = {
#             left = {
#               min = 0
#               max = 100
#             }
#           }
#         }
#         width  = 8
#         height = 6
#         x      = 0
#         y      = 18
#       },
#       {
#         type = "metric"
#         properties = {
#           title   = "Aurora Database Connections - All Clusters"
#           region  = "us-east-1"
#           metrics = [
#             ["AWS/RDS", "DatabaseConnections", { region = "us-east-1", stat = "Average", label = "Primary (US-East)" }],
#             ["AWS/RDS", "DatabaseConnections", { region = "ap-northeast-2", stat = "Average", label = "Seoul" }],
#             ["AWS/RDS", "DatabaseConnections", { region = "us-west-2", stat = "Average", label = "US-West" }]
#           ]
#           period = 60
#           stat   = "Average"
#           yAxis = {
#             left = {
#               min = 0
#             }
#           }
#         }
#         width  = 8
#         height = 6
#         x      = 8
#         y      = 18
#       },
#       {
#         type = "metric"
#         properties = {
#           title   = "Aurora Replication Lag (Secondaries)"
#           region  = "us-east-1"
#           metrics = [
#             ["AWS/RDS", "AuroraGlobalDBReplicationLag", { region = "ap-northeast-2", stat = "Average", label = "Seoul" }],
#             ["AWS/RDS", "AuroraGlobalDBReplicationLag", { region = "us-west-2", stat = "Average", label = "US-West" }]
#           ]
#           period = 60
#           stat   = "Average"
#           yAxis = {
#             left = {
#               min = 0
#             }
#           }
#         }
#         width  = 8
#         height = 6
#         x      = 16
#         y      = 18
#       },
# 
#       # Row 5: Custom Application Metrics
#       {
#         type = "metric"
#         properties = {
#           title   = "Application Latency Measurements"
#           region  = "us-east-1"
#           metrics = [
#             ["HyundaiPOC/Application", "LatencyMeasurement", { stat = "Average" }]
#           ]
#           period = 60
#           stat   = "Average"
#           yAxis = {
#             left = {
#               min = 0
#             }
#           }
#         }
#         width  = 24
#         height = 6
# #         x      = 0
# #         y      = 24
# #       }
# #     ]
# #   })
# # }
