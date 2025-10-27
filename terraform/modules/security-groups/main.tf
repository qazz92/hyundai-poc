# Security Groups Module
# Creates security groups for ALB, ECS, and Aurora with least-privilege access

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ALB Security Group
resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-alb-${var.region_name}-"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  # Allow HTTP from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP traffic from internet"
  }

  # Allow HTTPS from anywhere
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS traffic from internet"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-alb-sg-${var.region_name}"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# ECS Security Group
resource "aws_security_group" "ecs" {
  name_prefix = "${var.project_name}-ecs-${var.region_name}-"
  description = "Security group for ECS Fargate tasks"
  vpc_id      = var.vpc_id

  # Allow frontend traffic from ALB (port 3000)
  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "Allow frontend traffic from ALB"
  }

  # Allow backend traffic from ALB (port 3001)
  ingress {
    from_port       = 3001
    to_port         = 3001
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "Allow backend traffic from ALB"
  }

  # Allow HTTPS to internet (for AWS API calls, ECR, CloudWatch)
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS to AWS services"
  }

  # Allow HTTP for latency measurements to peer regions
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP for latency measurements"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-ecs-sg-${var.region_name}"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Separate rule for ECS to Aurora (breaks circular dependency)
resource "aws_security_group_rule" "ecs_to_aurora" {
  type                     = "egress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.ecs.id
  source_security_group_id = aws_security_group.aurora.id
  description              = "Allow MySQL to Aurora"
}

# Aurora Security Group
resource "aws_security_group" "aurora" {
  name_prefix = "${var.project_name}-aurora-${var.region_name}-"
  description = "Security group for Aurora database cluster"
  vpc_id      = var.vpc_id

  # No outbound rules needed (database doesn't initiate connections)

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-aurora-sg-${var.region_name}"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Separate rule for Aurora from ECS (breaks circular dependency)
resource "aws_security_group_rule" "aurora_from_ecs" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.aurora.id
  source_security_group_id = aws_security_group.ecs.id
  description              = "Allow MySQL from ECS tasks only"
}
