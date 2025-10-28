# Aurora Global Database Module
# Creates Aurora Serverless v2 MySQL with global database replication

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# KMS Key for Aurora Encryption (required for cross-region replicas)
resource "aws_kms_key" "aurora" {
  description             = "${var.project_name} Aurora encryption key - ${var.region_name}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-aurora-kms-${var.region_name}"
    }
  )
}

resource "aws_kms_alias" "aurora" {
  name          = "alias/${var.project_name}-aurora-${var.region_name}"
  target_key_id = aws_kms_key.aurora.key_id
}

# DB Subnet Group
resource "aws_db_subnet_group" "aurora" {
  name_prefix = "${var.project_name}-aurora-subnet-${var.region_name}-"
  subnet_ids  = var.private_subnet_ids

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-aurora-subnet-group-${var.region_name}"
    }
  )
}

# Aurora Global Cluster (only create in primary region)
resource "aws_rds_global_cluster" "main" {
  count                     = var.is_primary ? 1 : 0
  global_cluster_identifier = "${var.project_name}-global"
  engine                    = "aurora-mysql"
  engine_version            = "8.0.mysql_aurora.3.04.0"
  database_name             = var.db_name
  storage_encrypted         = true

  lifecycle {
    prevent_destroy = false
  }
}

# Aurora Cluster
resource "aws_rds_cluster" "aurora" {
  cluster_identifier = "${var.project_name}-cluster-${var.region_name}"

  # Global cluster configuration
  global_cluster_identifier = var.is_primary ? aws_rds_global_cluster.main[0].id : var.global_cluster_id

  engine         = "aurora-mysql"
  engine_mode    = "provisioned"
  engine_version = "8.0.mysql_aurora.3.04.0"

  # Database configuration
  database_name   = var.is_primary ? var.db_name : null
  master_username = var.is_primary ? var.master_username : null
  master_password = var.is_primary ? var.master_password : null

  # Network configuration
  db_subnet_group_name   = aws_db_subnet_group.aurora.name
  vpc_security_group_ids = [var.security_group_id]

  # Serverless v2 scaling configuration
  serverlessv2_scaling_configuration {
    min_capacity = var.min_capacity
    max_capacity = var.max_capacity
  }

  # Backup configuration
  backup_retention_period      = 7
  preferred_backup_window      = "03:00-04:00"
  preferred_maintenance_window = "sun:04:00-sun:05:00"

  # Additional settings
  storage_encrypted               = true
  kms_key_id                      = aws_kms_key.aurora.arn
  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]
  skip_final_snapshot            = true
  apply_immediately              = true

  tags = merge(
    var.tags,
    {
      Name       = "${var.project_name}-aurora-cluster-${var.region_name}"
      IsPrimary  = var.is_primary
      GlobalRole = var.is_primary ? "primary" : "secondary"
    }
  )

  depends_on = [
    aws_rds_global_cluster.main
  ]

  lifecycle {
    ignore_changes = [
      global_cluster_identifier,
      replication_source_identifier,
      database_name,
      master_username,
      master_password,
      engine_version  # 버전 업그레이드 시에도 drift 발생 가능
    ]
  }

}

# Aurora Cluster Instance - Writer (Primary only) or Reader (all regions)
resource "aws_rds_cluster_instance" "aurora" {
  count              = var.is_primary ? 2 : 1
  identifier         = "${var.project_name}-instance-${var.region_name}${count.index > 0 ? "-${count.index}" : ""}"
  cluster_identifier = aws_rds_cluster.aurora.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.aurora.engine
  engine_version     = aws_rds_cluster.aurora.engine_version

  # Performance Insights
  performance_insights_enabled = true

  # Enhanced Monitoring (disabled to avoid requiring monitoring role)
  monitoring_interval = 0

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-aurora-instance-${var.region_name}${count.index > 0 ? "-reader" : var.is_primary ? "-writer" : "-reader"}"
      Role = count.index == 0 && var.is_primary ? "writer" : "reader"
    }
  )
}

# CloudWatch Alarms for monitoring
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.project_name}-aurora-cpu-high-${var.region_name}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors Aurora CPU utilization"
  alarm_actions       = []

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.aurora.cluster_identifier
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "database_connections_high" {
  alarm_name          = "${var.project_name}-aurora-connections-high-${var.region_name}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "100"
  alarm_description   = "This metric monitors Aurora database connections"
  alarm_actions       = []

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.aurora.cluster_identifier
  }

  tags = var.tags
}

# Replication lag alarm (for secondary regions only)
resource "aws_cloudwatch_metric_alarm" "replication_lag_high" {
  count               = var.is_primary ? 0 : 1
  alarm_name          = "${var.project_name}-aurora-replication-lag-${var.region_name}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "AuroraGlobalDBReplicationLag"
  namespace           = "AWS/RDS"
  period              = "60"
  statistic           = "Average"
  threshold           = "1000"
  alarm_description   = "This metric monitors Aurora Global Database replication lag"
  alarm_actions       = []

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.aurora.cluster_identifier
  }

  tags = var.tags
}
