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
