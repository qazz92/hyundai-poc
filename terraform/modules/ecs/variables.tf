# ECS Module Variables

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "region_name" {
  description = "Region name for resource naming (seoul, us_east, us_west)"
  type        = string
}

variable "aws_region" {
  description = "AWS region code"
  type        = string
}

variable "task_cpu" {
  description = "Task CPU units"
  type        = string
  default     = "256"
}

variable "task_memory" {
  description = "Task memory in MB"
  type        = string
  default     = "512"
}

variable "desired_count" {
  description = "Desired number of tasks"
  type        = number
  default     = 2
}

variable "frontend_image" {
  description = "Frontend container image URI"
  type        = string
}

variable "backend_image" {
  description = "Backend container image URI"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "ecs_security_group_id" {
  description = "Security group ID for ECS tasks"
  type        = string
}

variable "execution_role_arn" {
  description = "ARN of ECS task execution role"
  type        = string
}

variable "task_role_arn" {
  description = "ARN of ECS task role"
  type        = string
}

variable "frontend_target_group_arn" {
  description = "ARN of frontend target group"
  type        = string
}

variable "backend_target_group_arn" {
  description = "ARN of backend target group"
  type        = string
}

variable "alb_listener_arn" {
  description = "ARN of ALB listener"
  type        = string
}

variable "db_writer_endpoint" {
  description = "Aurora writer endpoint"
  type        = string
}

variable "db_reader_endpoint" {
  description = "Aurora reader endpoint"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "db_username" {
  description = "Database username"
  type        = string
}

variable "db_password_secret_arn" {
  description = "ARN of Secrets Manager secret containing database password"
  type        = string
}

variable "backend_url" {
  description = "Backend API URL for frontend"
  type        = string
}

variable "domain_name" {
  description = "Domain name for Route53 hosted zone"
  type        = string
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "enable_frontend" {
  description = "Enable frontend service (set to false to remove frontend from region)"
  type        = bool
  default     = true
}
