# Root Terraform Variables

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "hyundai-poc"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "interview"
}

variable "regions" {
  description = "AWS regions configuration"
  type = object({
    seoul   = string
    us_east = string
    us_west = string
  })
  default = {
    seoul   = "ap-northeast-2"
    us_east = "us-east-1"
    us_west = "us-west-2"
  }
}

variable "vpc_cidrs" {
  description = "VPC CIDR blocks for each region"
  type = object({
    seoul   = string
    us_east = string
    us_west = string
  })
  default = {
    seoul   = "10.0.0.0/16"
    us_east = "10.1.0.0/16"
    us_west = "10.2.0.0/16"
  }
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "hyundai_poc"
}

variable "db_master_username" {
  description = "Database master username"
  type        = string
  default     = "admin"
}

variable "db_master_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}

variable "aurora_serverless_min_capacity" {
  description = "Minimum Aurora Serverless v2 capacity units"
  type        = number
  default     = 0.5
}

variable "aurora_serverless_max_capacity" {
  description = "Maximum Aurora Serverless v2 capacity units"
  type        = number
  default     = 2
}

variable "ecs_cpu" {
  description = "ECS task CPU units"
  type        = string
  default     = "256"
}

variable "ecs_memory" {
  description = "ECS task memory in MB"
  type        = string
  default     = "512"
}

variable "domain_name" {
  description = "Domain name for Route53 hosted zone (optional - can use ALB DNS directly)"
  type        = string
  default     = "hyundai-poc.com"
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "Hyundai-POC"
    Environment = "Interview"
    ManagedBy   = "Terraform"
  }
}
