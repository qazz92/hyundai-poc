# Monitoring Module Variables

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "interview"
}

variable "create_firehose" {
  description = "Whether to create Kinesis Data Firehose for metric streaming"
  type        = bool
  default     = true
}

# Regional ECS Cluster Names
variable "seoul_ecs_cluster_name" {
  description = "Seoul ECS cluster name"
  type        = string
}

variable "us_east_ecs_cluster_name" {
  description = "US-East ECS cluster name"
  type        = string
}

variable "us_west_ecs_cluster_name" {
  description = "US-West ECS cluster name"
  type        = string
}

# Regional ECS Service Names
variable "seoul_frontend_service_name" {
  description = "Seoul frontend service name"
  type        = string
}

variable "seoul_backend_service_name" {
  description = "Seoul backend service name"
  type        = string
}

variable "us_east_frontend_service_name" {
  description = "US-East frontend service name"
  type        = string
}

variable "us_east_backend_service_name" {
  description = "US-East backend service name"
  type        = string
}

variable "us_west_frontend_service_name" {
  description = "US-West frontend service name"
  type        = string
}

variable "us_west_backend_service_name" {
  description = "US-West backend service name"
  type        = string
}

# Regional ALB ARN Suffixes (for CloudWatch dimensions)
variable "seoul_alb_arn_suffix" {
  description = "Seoul ALB ARN suffix"
  type        = string
}

variable "us_east_alb_arn_suffix" {
  description = "US-East ALB ARN suffix"
  type        = string
}

variable "us_west_alb_arn_suffix" {
  description = "US-West ALB ARN suffix"
  type        = string
}

# Regional Target Group ARN Suffixes
variable "seoul_frontend_tg_arn_suffix" {
  description = "Seoul frontend target group ARN suffix"
  type        = string
}

variable "seoul_backend_tg_arn_suffix" {
  description = "Seoul backend target group ARN suffix"
  type        = string
}

variable "us_east_frontend_tg_arn_suffix" {
  description = "US-East frontend target group ARN suffix"
  type        = string
}

variable "us_east_backend_tg_arn_suffix" {
  description = "US-East backend target group ARN suffix"
  type        = string
}

variable "us_west_frontend_tg_arn_suffix" {
  description = "US-West frontend target group ARN suffix"
  type        = string
}

variable "us_west_backend_tg_arn_suffix" {
  description = "US-West backend target group ARN suffix"
  type        = string
}

# Firehose Configuration
variable "firehose_buffer_size" {
  description = "Firehose buffer size in MB"
  type        = number
  default     = 5
}

variable "firehose_buffer_interval" {
  description = "Firehose buffer interval in seconds"
  type        = number
  default     = 60
}

variable "firehose_compression" {
  description = "Firehose compression format"
  type        = string
  default     = "GZIP"
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
