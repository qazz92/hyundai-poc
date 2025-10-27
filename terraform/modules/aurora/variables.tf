# Aurora Module Variables

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "region_name" {
  description = "Region name for resource naming (seoul, us_east, us_west)"
  type        = string
}

variable "is_primary" {
  description = "Whether this is the primary region (us-east-1)"
  type        = bool
  default     = false
}

variable "global_cluster_id" {
  description = "Global cluster ID (for secondary regions)"
  type        = string
  default     = null
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "master_username" {
  description = "Master username for database"
  type        = string
}

variable "master_password" {
  description = "Master password for database"
  type        = string
  sensitive   = true
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for Aurora"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for Aurora"
  type        = string
}

variable "min_capacity" {
  description = "Minimum Aurora Serverless v2 capacity units"
  type        = number
  default     = 0.5
}

variable "max_capacity" {
  description = "Maximum Aurora Serverless v2 capacity units"
  type        = number
  default     = 2
}

variable "monitoring_role_arn" {
  description = "ARN of IAM role for enhanced monitoring"
  type        = string
  default     = null
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
