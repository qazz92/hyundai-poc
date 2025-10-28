# ECS Module
# Creates ECS cluster, task definitions, and services for Fargate deployment

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster-${var.region_name}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-ecs-cluster-${var.region_name}"
    }
  )
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "frontend" {
  count = var.enable_frontend ? 1 : 0

  name              = "/ecs/${var.project_name}-frontend-${var.region_name}"
  retention_in_days = 7

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${var.project_name}-backend-${var.region_name}"
  retention_in_days = 7

  tags = var.tags
}

# Frontend Task Definition
resource "aws_ecs_task_definition" "frontend" {
  count = var.enable_frontend ? 1 : 0

  family                   = "${var.project_name}-frontend-${var.region_name}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  # Use ARM64 architecture (Graviton2) for 20% cost savings
  runtime_platform {
    cpu_architecture        = "ARM64"
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode([
    {
      name      = "frontend"
      image     = var.frontend_image
      essential = true

      portMappings = [
        {
          containerPort = 3000
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "NODE_ENV"
          value = "production"
        },
        {
          name  = "NEXT_PUBLIC_REGION"
          value = var.aws_region
        },
        {
          name  = "NEXT_PUBLIC_API_URL"
          value = var.backend_url
        },
        {
          name  = "NEXT_PUBLIC_ALB_SEOUL_URL"
          value = "https://api-direct-seoul.${var.domain_name}/health"
        },
        {
          name  = "NEXT_PUBLIC_ALB_US_EAST_URL"
          value = "https://api-direct-us-east.${var.domain_name}/health"
        },
        {
          name  = "NEXT_PUBLIC_ALB_US_WEST_URL"
          value = "https://api-direct-us-west.${var.domain_name}/health"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.frontend[0].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-frontend-task-${var.region_name}"
    }
  )
}

# Backend Task Definition
resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.project_name}-backend-${var.region_name}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  # Use ARM64 architecture (Graviton2) for 20% cost savings
  runtime_platform {
    cpu_architecture        = "ARM64"
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode([
    {
      name      = "backend"
      image     = var.backend_image
      essential = true

      portMappings = [
        {
          containerPort = 3001
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "NODE_ENV"
          value = "production"
        },
        {
          name  = "AWS_REGION"
          value = var.aws_region
        },
        {
          name  = "DB_WRITER_HOST"
          value = var.db_writer_endpoint
        },
        {
          name  = "DB_READER_HOST"
          value = var.db_reader_endpoint
        },
        {
          name  = "DB_PORT"
          value = "3306"
        },
        {
          name  = "DB_NAME"
          value = var.db_name
        },
        {
          name  = "DB_USER"
          value = var.db_username
        },
        {
          name  = "LOG_LEVEL"
          value = "info"
        }
      ]

      secrets = [
        {
          name      = "DB_PASSWORD"
          valueFrom = var.db_password_secret_arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.backend.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-backend-task-${var.region_name}"
    }
  )
}

# Frontend Service
resource "aws_ecs_service" "frontend" {
  count = var.enable_frontend ? 1 : 0

  name            = "${var.project_name}-frontend-service-${var.region_name}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.frontend[0].arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.frontend_target_group_arn
    container_name   = "frontend"
    container_port   = 3000
  }

  health_check_grace_period_seconds = 60

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-frontend-service-${var.region_name}"
    }
  )

  depends_on = [var.alb_listener_arn]

  lifecycle {
    ignore_changes = [ 
      task_definition
     ]
  }
}

# Backend Service
resource "aws_ecs_service" "backend" {
  name            = "${var.project_name}-backend-service-${var.region_name}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.backend_target_group_arn
    container_name   = "backend"
    container_port   = 3001
  }

  health_check_grace_period_seconds = 60

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-backend-service-${var.region_name}"
    }
  )

  depends_on = [var.alb_listener_arn]
}
